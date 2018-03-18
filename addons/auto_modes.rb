require 'axial/addon'
require 'axial/models/user'
require 'axial/models/mask'

module Axial
  module Addons
    class AutoModes < Axial::Addon
      def initialize()
        super

        @name    = 'auto modes'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_join    :auto_op
        on_privmsg 'exec', :privmsg_exec
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
