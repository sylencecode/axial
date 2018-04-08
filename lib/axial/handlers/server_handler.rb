module Axial
  module Handlers
    class ServerHandler
      def initialize(bot)
        @bot = bot
      end

      def dispatch_whois_uhost(nick_name, ident, host)
        if (nick_name.casecmp(@bot.real_nick).zero?)
          @bot.server_interface.myself.uhost = "#{nick_name}!#{ident}@#{host}"
        else
          LOGGER.debug("unhandled whois response for #{nick_name}: #{nick_name}!#{ident}@#{host}")
        end
      end

      def handle_server_notice(text)
        LOGGER.info("SERVER NOTICE: #{text}")
      end
    end
  end
end
