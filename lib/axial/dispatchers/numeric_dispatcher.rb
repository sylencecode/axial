require 'axial/handlers/patterns'


module Axial
  module Dispatchers
    class NumericDispatcher
      include Handlers::Patterns

      def initialize(bot)
        @bot = bot
      end

      def dispatch_numeric(captures)
        code, text = captures
        numeric_string = "#{code} #{text}"
        case numeric_string
          when Server::MOTD_END, Server::MOTD_ERROR
            LOGGER.info("performing autojoin")
            @bot.autojoin_channels
          when Server::MOTD_BEGIN
            LOGGER.debug(numeric_string)
          when Server::MOTD_ENTRY
            LOGGER.debug(numeric_string)
          when Channel::NOT_OPERATOR
            LOGGER.warn("I tried to do something to #{Regexp.last_match[1]} but I'm not opped.")
          when Channel::WHO_LIST_END
            @bot.channel_handler.handle_who_list_end(Regexp.last_match[1])
          when Channel::WHO_LIST_ENTRY
            channel_name, user, host, server, nick, mode, junk, realname = Regexp.last_match.captures
            uhost = "#{nick}!#{user}@#{host}"
            @bot.channel_handler.handle_who_list_entry(nick, uhost, channel_name, mode)
          when Channel::NAMES_LIST_ENTRY
            LOGGER.debug(numeric_string)
          when Channel::NAMES_LIST_END
            LOGGER.debug(numeric_string)
          when Server::PARAMETERS
            if (text =~ /MODES=(\d+)/)
              @bot.server.max_modes = Regexp.last_match[1]
            end
          else
            LOGGER.warn("[#{code}] #{text}")
        end
      end
    end
  end
end
