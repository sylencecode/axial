require 'axial/addon'
require 'axial/models/user'
require 'axial/models/mask'

module Axial
  module Addons
    class ChannelProtection < Axial::Addon
      def initialize()
        super

        @name    = 'channel protection'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        # :bans, :unbans, :invite_only, :keyword, :limit, :moderated, :no_outside_messages, :ops, :deops, :secret, :topic_ops_only, :voices, :devoices
        @enforce_modes = [ :topic_ops_only, :no_outside_messages ]
        @prevent_modes  = [ :invite_only, :limit, :keyword, :moderated ]
        on_join :auto_op
        on_privmsg 'exec', :privmsg_exec
        on_mode @prevent_modes, :handle_prevent_modes
        on_mode @enforce_modes, :handle_enforce_modes
        #on_mode :all, :handle_all
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
          channel.mode(response_mode)
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
          channel.mode(response_mode)
        end
      end

      def auto_op(channel, nick)
        begin
          #TODO: Only if you're opped. Make a queue for modes to set when opped?
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

      def privmsg_exec(nick, command)
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
