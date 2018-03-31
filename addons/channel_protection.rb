require 'axial/irc_types/nick'
require 'axial/addon'
require 'axial/axnet/complaint'

module Axial
  module Addons
    class ChannelProtection < Axial::Addon
      def initialize(bot)
        super

        @name    = 'channel protection'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        # :bans, :unbans, :invite_only, :keyword, :limit, :moderated, :no_outside_messages, :ops, :deops, :secret, :topic_ops_only, :voices, :devoices
        @enforce_modes              = [ :topic_ops_only, :no_outside_messages ]
        @prevent_modes              = [ :invite_only, :limit, :keyword, :moderated ]
        @op_deop_modes              = [ :ops, :deops ]
        @complaint_timer            = nil

        throttle                    2

        # axnet hooks
        on_startup                  :start_complaint_timer
        on_reload                   :start_complaint_timer
        on_axnet       'COMPLAINT', :handle_axnet_complaint
        on_self_join                :send_axnet_op_complaint
        # on banned response
        # on invite only, invite
        # on limit, increase or remove
        # on keyword, send keyword
        # if not joined to channels in autojoin list, etc..
        #on_mode :all, :handle_all

        # general mode/user management
        on_join                     :auto_op_voice
        on_join                     :auto_ban
        on_mode @prevent_modes,     :handle_prevent_modes
        on_mode @enforce_modes,     :handle_enforce_modes
        on_mode @op_deop_modes,     :handle_op_deop
        on_mode :bans,              :protect_banned_users
        on_user_list                :check_for_new_users
        on_ban_list                 :check_for_new_bans
        on_self_kick                :rejoin
        # create a timer for checking channel bans every minute, use banlist response to check timestamps

        # on kick...protect the people

        # commands
        on_privmsg      'exec',     :handle_privmsg_exec
        on_channel    '?topic',     :handle_topic
      end

      def get_bot_or_user(nick)
        possible_user = @bot.user_list.get_from_nick_object(nick)
        if (possible_user.nil?)
          possible_user = @bot.bot_list.get_from_nick_object(nick)
        end
        return possible_user
      end

      def get_bot_or_user_mask(mask)
        possible_user = @bot.user_list.get_user_from_mask(mask)
        if (possible_user.nil?)
          possible_user = @bot.bot_list.get_user_from_mask(mask)
        end
        return possible_user
      end

      def get_bots_or_users_mask(mask)
        bots_or_users = []
        @bot.user_list.get_users_from_mask(mask).each do |tmp_mask|
          bots_or_users.push(tmp_mask)
        end
        @bot.bot_list.get_users_from_mask(mask).each do |tmp_mask|
          bots_or_users.push(tmp_mask)
        end
        return bots_or_users
      end


      def rejoin(channel, kicker_nick, reason)
        # TODO: get the password out of the database or out of the bot props yaml if one is set
        wait_a_sec
        @server_interface.join(channel.name)
      end

      def check_for_new_users()
        @bot.server_interface.channel_list.all_channels.each do |channel|
          check_channel_users(channel)
        end
      end

      def check_for_new_bans()
        @bot.server_interface.channel_list.all_channels.each do |channel|
          check_channel_bans(channel)
        end
      end

      def remove_old_irc_bans(channel)
        # TODO: timer to remove hour-old bans
        # (Time.now - Time.at(1521931658))
      end

      def check_channel_bans(channel)
        if (!channel.opped?)
          return
        end

        response_mode = IRCTypes::Mode.new
        kicks = []
        @bot.ban_list.all_bans.each do |ban|
          channel.nick_list.all_nicks.each do |nick|
            if (ban.match_mask?(nick.uhost))
              if (!response_mode.bans.include?(ban.mask))
                response_mode.ban(ban.mask)
              end
              kicks.push(nick: nick, reason: ban.long_reason)
            end
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
        kicks.each do |kick|
          channel.kick(kick[:nick], kick[:reason])
        end
      end

      def check_channel_users(channel)
        if (!channel.opped?)
          return
        end

        wait_a_sec

        response_mode = IRCTypes::Mode.new
        channel.nick_list.all_nicks.each do |subject_nick|
          possible_user = get_bot_or_user(subject_nick)
          if (possible_user.nil?)
            next
          elsif (possible_user.op? || possible_user.bot?)
            if (!subject_nick.opped_on?(channel))
              response_mode.op(subject_nick.name)
            end
          elsif (possible_user.friend?)
            if (!subject_nick.voiced_on?(channel))
              response_mode.voice(subject_nick.name)
            end
          # else
          # if (subject_nick.opped_on?(channel))
          #   response_mode.deop(subject_nick.name)
          # elsif (subject_nick.voiced_on?(channel))
          #   response_mode.devoice(subject_nick.name)
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end


      def stop_complaint_timer()
        LOGGER.debug("stopping complaint timer")
        @bot.timer.delete(@complaint_timer)
      end

      def start_complaint_timer()
        LOGGER.debug("starting complaint timer")
        @complaint_timer = @bot.timer.every_30_seconds(self, :check_for_complaints)
      end

      def check_for_complaints()
        @server_interface.channel_list.all_channels.each do |channel|
          if (!channel.synced?)
            return
          end

          if (!channel.opped?)
            send_axnet_op_complaint(channel)
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_axnet_complaint(handler, command)
        serialized_yaml = command.args
        @bot.axnet.relay_to_axnet(handler, 'COMPLAINT ' + serialized_yaml)
        complaint = YAML.load(serialized_yaml.gsub(/\0/, "\n"))
        bot = IRCTypes::Nick.from_uhost(@server_interface, complaint.uhost)

        if (bot.nil?)
          return
        end

        if (complaint.type == :deopped)
          channel = @server_interface.channel_list.get_silent(complaint.channel_name)

          if (channel.nil?)
            return
          elsif (!channel.synced?)
            return
          elsif (!channel.opped?)
            return
          end

          channel_nick = channel.nick_list.get_silent(bot.name)
          if (channel_nick.nil?)
            return
          end

          wait_a_sec

          if (!channel_nick.opped_on?(channel))
            channel.op(channel_nick)
          end
        end
      end

      def send_axnet_op_complaint(channel)
        if (!channel.opped?)
          complain(channel, :deopped)
        end
      end

      def send_complaint(complaint)
        serialized_yaml = YAML.dump(complaint).gsub(/\n/, "\0")
        @bot.axnet.transmit_to_axnet('COMPLAINT ' + serialized_yaml)
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

      def protect_banned_users(channel, nick, mode)
        if (!channel.opped? || nick == @server_interface.myself)
          return
        end

        user = get_bot_or_user(nick)
        response_mode = IRCTypes::Mode.new

        mode.bans.each do |in_mask|
          mask = in_mask.strip
          possible_users = get_bots_or_users_mask(mask)
          if (@server_interface.myself.match_mask?(mask) || possible_users.any?)
            if (!bot_or_director?(user))
              channel.unban(mask)
              if (!nick.is_a?(IRCTypes::Server) && nick.opped_on?(channel))
                channel.deop(nick.name)
              end
            end
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_op_deop(channel, nick, mode)
        if (!channel.opped? || nick == @server_interface.myself)
          return
        end

        if (mode.ops.any?)
          response_mode = IRCTypes::Mode.new
          mode.ops.each do |op|
            if (op == @server_interface.myself.name)
              channel.opped = true
              check_channel_bans(channel)
              check_channel_users(channel)
            else
              subject_nick = channel.nick_list.get(op)
              possible_user = get_bot_or_user(subject_nick)
              if (possible_user.nil? || !possible_user.op?)
                if (!bot_or_director?(user))
                  if (!subject_nick.opped_on?(channel))
                    response_mode.deop(subject_nick.name)
                  end
                end
              end
            end
          end
        end

        if (mode.deops.any?)
          mode.deops.each do |deop|
            if (deop == @server_interface.myself.name)
              channel.opped = false
              send_axnet_op_complaint(channel)
            else
              # re-op users and penalize offender unless deopped by a director or bot
              subject_nick = channel.nick_list.get(deop)
              possible_user = get_bot_or_user(subject_nick)
              if (!possible_user.nil? && possible_user.op?)
                if (!bot_or_director?(user))
                  if (!subject_nick.opped_on?(channel))
                    response_mode.op(subject_nick.name)
                  end
                  if (!nick.is_a?(IRCTypes::Server) && nick.opped_on?(channel))
                    # immediate
                    channel.deop(nick.name)
                  end
                end
              end
            end
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end

      def bot_or_director?(user)
        return (!user.nil? && (user.bot? || user.director?))
      end

      def handle_prevent_modes(channel, nick, mode)
        if (!channel.opped? || nick == @server_interface.myself)
          return
        end

        user = get_bot_or_user(nick)
        if (bot_or_director?(user))
          return
        end

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

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_enforce_modes(channel, nick, mode)
        if (!channel.opped? || nick == @server_interface.myself)
          return
        end

        user = get_bot_or_user(nick)
        if (bot_or_director?(user))
          return
        end

        response_mode = IRCTypes::Mode.new
        mode.channel_modes.each do |channel_mode|
          mode_set = mode.public_send((channel_mode.to_s + '?').to_sym)
          if (!mode_set)
            response_mode.public_send((channel_mode.to_s + '=').to_sym, true)
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end

      def auto_op_voice(channel, nick)
        if (!channel.opped? || nick == @server_interface.myself)
          return
        end

        wait_a_sec
        user = get_bot_or_user_mask(nick.uhost)
        if (!user.nil?)
          if (user.op?)
            if (!nick.opped_on?(channel))
              channel.op(nick)
              LOGGER.info("auto-opped #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
            end
          elsif (user.friend?)
            if (!nick.voiced_on?(channel))
              channel.voice(nick)
              LOGGER.info("auto-voiced #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
            end
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def auto_ban(channel, nick)
        if (!channel.opped? || nick == @server_interface.myself)
          return
        end

        user = get_bot_or_user_mask(nick.uhost)
        if (user.nil?)
          @bot.ban_list.all_bans.each do |ban|
            if (ban.match_mask?(nick.uhost))
              response_mode = IRCTypes::Mode.new
              response_mode.ban(ban.mask)
              channel.set_mode(response_mode)
              channel.kick(nick, ban.long_reason)
            end
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_privmsg_exec(nick, command)
        user = get_bot_or_user(nick)
        if (user.nil? || !user.director?)
          nick.message(Constants::ACCESS_DENIED)
          return
        end
        @server_interface.send_raw(command.args)
        LOGGER.info("#{nick.name} EXEC #{command.args.inspect}")
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping complaint timer")
        stop_complaint_timer
      end
    end
  end
end
