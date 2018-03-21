require 'axial/addon'
require 'axial/models/user'
require 'axial/models/mask'

module Axial
  module Addons
    class ChannelProtection < Axial::Addon
      def initialize(server_interface)
        super

        @name    = 'channel protection'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        # :bans, :unbans, :invite_only, :keyword, :limit, :moderated, :no_outside_messages, :ops, :deops, :secret, :topic_ops_only, :voices, :devoices
        @enforce_modes          = [ :topic_ops_only, :no_outside_messages ]
        @prevent_modes          = [ :invite_only, :limit, :keyword, :moderated ]
        @op_deop_modes          = [ :ops, :deops ]
        @ban_modes              = [ :bans, :unbans ]

        throttle                2
        on_join                 :handle_auto_op
        on_privmsg      'exec', :handle_privmsg_exec
        on_privmsg      'chatto', :send_dcc_chat_offer
        on_channel     'topic', :handle_topic
        on_mode @prevent_modes, :handle_prevent_modes
        on_mode @enforce_modes, :handle_enforce_modes
        on_mode @op_deop_modes, :handle_op_deop
        on_mode @ban_modes,     :handle_ban_unban
        on_nick_change          :handle_nick_change
        #on_mode :all, :handle_all
      end

      def handle_nick_change(old_nick, new_nick)
        LOGGER.debug("#{self.class} received a nick change from #{old_nick.name} to #{new_nick.name}")
      end

      def handle_ban_unban(channel, nick, mode)
        response_mode = IRCTypes::Mode.new
        if (mode.bans.any?)
          if (nick == @server_interface.myself)
            # kick, do something, etc
            # need channel.ban_list
            # set an unban timer?
          else
            mode.bans.each do |in_mask|
              mask = in_mask.strip
              possible_users = Models::Mask.get_users_from_mask(mask)
              cantban = possible_users.collect{|user| user.name}
              if (possible_users.any?)
                channel.message("#{nick.name}: you can't ban #{cantban.join(', ')}")
                response_mode.unban(mask)
              end
            end
          end
        end

        if (mode.unbans.any?)
          if (nick == @server_interface.myself)
            # kick, do something, etc
            # need channel.ban_list
          end
        end

        if (response_mode.to_string_array.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_op_deop(channel, nick, mode)
        return
        # if (mode.ops.any?)
        #   if (nick == @server_interface.myself)
        #     channel.message("I opped #{mode.ops.inspect}")
        #   else
        #     channel.message("#{nick.name} opped #{mode.ops.inspect}")
        #   end
        # end
        # if (mode.deops.any?)
        #   if (nick == @server_interface.myself)
        #     channel.message("I voiced #{mode.ops.inspect}")
        #   else
        #     channel.message("#{nick.name} voiced #{mode.ops.inspect}")
        #   end
        # end
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

          user = Models::Mask.get_user_from_mask(nick.uhost)
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
        user_model = Models::User.get_from_nick_object(nick)
        if (user_model.nil? || !user_model.director?)
          nick.message(Constants::ACCESS_DENIED)
          return
        end
        @server_interface.send_raw(command.args)
        LOGGER.info("#{nick.name} EXEC #{command.args.inspect}")
      end
    end
  end
end