module Axial
  module Handlers
    class ServerHandler
      def initialize(bot)
        @bot = bot
      end

      def handle_ison_reply(nicks)
        nick_names = nicks.split(/\s+/)
        if (!nick_names.include?(@bot.nick))
          LOGGER.debug("nick '#{@bot.nick}' appears to be available. attempting nick change.")
          @bot.trying_nick = @bot.nick
          @bot.connection_handler.try_nick
        end
      end

      def handle_whois_uhost(nick_name, ident, host)
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
