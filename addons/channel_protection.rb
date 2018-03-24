require 'axial/irc_types/nick'
require 'axial/axnet/complaint'
require 'axial/consumers/raw_consumer'
require 'axial/addon'

module Axial
  module Addons
    class ChannelProtection < Axial::Addon
      def initialize(bot)
        super

        @name    = 'channel protection'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        # :bans, :unbans, :invite_only, :keyword, :limit, :moderated, :no_outside_messages, :ops, :deops, :secret, :topic_ops_only, :voices, :devoices
        @enforce_modes              = [ :topic_ops_only, :no_outside_messages ]
        @prevent_modes              = [ :invite_only, :limit, :keyword, :moderated ]
        @op_deop_modes              = [ :ops, :deops ]
        @ban_modes                  = [ :bans, :unbans ]
        @complaint_thread           = nil

        throttle                    2
        on_startup                  :start_complaint_thread
        on_reload                   :start_complaint_thread
        on_join                     :handle_auto_op
        on_privmsg      'exec',     :handle_privmsg_exec
        on_privmsg    'chatto',     :send_dcc_chat_offer
        on_channel     'topic',     :handle_topic
        on_mode @prevent_modes,     :handle_prevent_modes
        on_mode @enforce_modes,     :handle_enforce_modes
        on_mode @op_deop_modes,     :handle_op_deop
        on_mode @ban_modes,         :handle_ban_unban
        on_nick_change              :handle_nick_change
        on_axnet   'COMPLAINT',     :handle_axnet_complaint
        # on kick...
        # on banned response
        # on invite only, invite
        # on limit, increase or remove
        # on keyword, send keyword
        # if not joined to channels in autojoin list, etc..
        #on_mode :all, :handle_all
      end

      def stop_complaint_thread()
        LOGGER.debug("stopping ingest thread")
        @complaining = false
        if (!@complaint_thread.nil?)
          @complaint_thread.kill
        end
        @complaint_thread = nil
      end

      def start_complaint_thread()
        LOGGER.debug("starting complaint thread")
        @complaining = true
        @complaint_thread = Thread.new do
          while (@complaining)
            sleep 1
            begin
              @server_interface.channel_list.all_channels.each do |channel|
                LOGGER.debug("checking #{channel.name} for complaints")
                if (!channel.synced?)
                  LOGGER.debug("#{channel.name} is not synced, not complaining")
                  return
                end

                if (!channel.opped?)
                  LOGGER.debug("complaining about not being opped on #{channel.name}")
                  complain(channel, :deopped)
                end
              end
            rescue Exception => ex
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      end

      def handle_axnet_complaint(handler, command)
        serialized_yaml = command.args
        LOGGER.debug("received complaint from #{handler.remote_cn}: #{serialized_yaml.inspect}")
        @bot.axnet_interface.relay_to_axnet(handler, serialized_yaml)
        complaint = YAML.load(serialized_yaml.gsub(/\0/, "\n"))
        bot = IRCTypes::Nick.from_uhost(@server_interface, complaint.uhost)

        if (bot.nil?)
          LOGGER.debug("can't help #{complaint.uhost} - can't build a nick object")
          return
        end

        if (complaint.type == :deopped)
          channel = @server_interface.channel_list.get_silent(complaint.channel_name)

          if (channel.nil?)
            LOGGER.debug("can't help #{bot.name} - not on #{complaint.channel_name}")
            return
          elsif (!channel.synced?)
            LOGGER.debug("can't help #{bot.name} - #{channel.name} is not synced yet")
            return
          elsif (!channel.opped?)
            LOGGER.debug("can't help #{bot.name} - not an op #{channel.name}")
            return
          end

          channel_nick = channel.nick_list.get_silent(bot)
          if (channel_nick.nil)
            LOGGER.debug("can't help #{bot.name} - cannot find nickname in #{channel.name}")
            return
          end

          LOGGER.info("trying to op #{channel_nick.name}")
          channel.op(channel_nick)
        end
      end

      def send_complaint(complaint)
        LOGGER.debug("sending complaint: #{complaint.inspect}")
        serialized_yaml = YAML.dump(complaint).gsub(/\n/, "\0")
        @bot.axnet_interface.transmit_to_axnet('COMPLAINT ' + serialized_yaml)
      end

      def complain(channel, complaint_type)
        # :deopped, :banned, :invite, :keyword, :limit
        complaint                 = Axnet::Complaint.new
        complaint.uhost           = @bot.server_interface.myself.uhost
        complaint.type            = complaint_type

        if (channel.is_a?(IRCTypes::Channel))
          complaint.channel_name  = channel.name
        else
          complaint.channel_name  = channel
        end
        send_complaint(complaint)
      end

      def handle_nick_change(old_nick, new_nick)
        LOGGER.debug("#{self.class} received a nick change from #{old_nick.name} to #{new_nick.name}")
      end

      def handle_ban_unban(channel, nick, mode)
        if (!channel.opped?)
          return
        end
        response_mode = IRCTypes::Mode.new
        if (mode.bans.any?)
          if (nick == @server_interface.myself)
            # kick, do something, etc
            # need channel.ban_list
            # set an unban timer?
          else
            mode.bans.each do |in_mask|
              mask = in_mask.strip
              possible_users = @bot.user_list.get_users_from_mask(mask)
              cantban = possible_users.collect{|user| user.name}
              channel.message("#{nick.name}: #{in_mask} would ban protected users: #{cantban.join(', ')}")
              if (possible_users.any?)
                response_mode.unban(mask)
              else
                # kick
              end
            end
          end
        end

        if (mode.unbans.any?)
          if (nick == @server_interface.myself)
            # kick, do something, etc
            # need channel.ban_list
          else
            # check sticky ban list
          end
        end

        if (response_mode.to_string_array.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_op_deop(channel, nick, mode)
        if (!channel.opped?)
          return
        end

        response_mode = IRCTypes::Mode.new
        if (mode.ops.any?)
          if (nick == @server_interface.myself)
            LOGGER.debug("I opped #{mode.ops.inspect}")
          else
            mode.ops.each do |op|
              if (op == @server_interface.myself.name)
                channel.opped = true
              else
                subject_nick = channel.nick_list.get(op)
                possible_user = @bot.user_list.get_from_nick_object(subject_nick)
                paranoid = false
                if (paranoid && (possible_user.nil? || !possible_user.op?))
                  response_mode.deop(subject_nick.name)
                end
              end
            end
          end
        end

        if (mode.deops.any?)
          if (nick == @server_interface.myself)
            LOGGER.debug("I deopped #{mode.deops.inspect}")
          else
            mode.deops.each do |deop|
              if (deop == @server_interface.myself.name)
                channel.opped = false
                complain(channel, :deopped)
              else
                subject_nick = channel.nick_list.get(deop)
                possible_user = @bot.user_list.get_from_nick_object(subject_nick)
                if (!possible_user.nil? && possible_user.op?)
                  response_mode.op(subject_nick.name)
                end
              end
            end
          end
        end

        if (response_mode.to_string_array.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_prevent_modes(channel, nick, mode)
        response_mode = IRCTypes::Mode.new
        mode.channel_modes.each do |channel_mode|
          mode_set = mode.public_send((channel_mode.to_s + '?').to_sym)
          if (mode_set)
            if (channel_mode == :keyword)
              response_mode.unset_keyword(mode.keyword)
            elsif (channel_mode == :limit)
              response_mode.limit = 0
            else
              response_mode.public_send((channel_mode.to_s + '=').to_sym, false)
            end
          end
        end

        if (response_mode.to_string_array.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_enforce_modes(channel, nick, mode)
        response_mode = IRCTypes::Mode.new
        mode.channel_modes.each do |channel_mode|
          mode_set = mode.public_send((channel_mode.to_s + '?').to_sym)
          if (!mode_set)
            response_mode.public_send((channel_mode.to_s + '=').to_sym, true)
          end
        end

        if (response_mode.to_string_array.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_auto_op(channel, nick)
        begin
          if (!channel.opped?)
            return
          end

          user = @bot.user_list.get_user_from_mask(nick.uhost)
          if (!user.nil?)
            if (user.op?)
              channel.op(nick)
              LOGGER.info("auto-opped #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
            elsif (user.friend?)
              channel.voice(nick)
              LOGGER.info("auto-voiced #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
            end
          end
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def send_dcc_chat_offer(nick, command)
        LOGGER.debug("dcc chat offer to #{nick.name}")
        ip = '74.208.183.199'

        fragments = ip.split('.')

        long_ip = 0

        block = 4
        fragments.each do |fragment|
          block -= 1
          long_ip += fragment.to_i * (256 ** block)
        end

        nick.message("\x01DCC CHAT chat #{long_ip} 6667\x01")
      end

      def handle_privmsg_exec(nick, command)
        user = @bot.user_list.get_from_nick_object(nick)
        if (user.nil? || !user.director?)
          nick.message(Constants::ACCESS_DENIED)
          return
        end
        @server_interface.send_raw(command.args)
        LOGGER.info("#{nick.name} EXEC #{command.args.inspect}")
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping complaint thread")
        stop_complaint_thread
      end
    end
  end
end
