require 'axial/handlers/patterns'

module Axial
  module Dispatchers
    class ServerMessageDispatcher
      include Handlers::Patterns

      def initialize(bot)
        @bot = bot
      end

      def dispatch(text)
        case text
          when Channel::JOIN
            @bot.channel_handler.dispatch_join(Regexp.last_match.captures)
          when Channel::MODE
            @bot.channel_handler.dispatch_mode(Regexp.last_match.captures)
          when Channel::NOT_OPERATOR
            LOGGER.warn("I tried to do something to #{Regexp.last_match[1]} but I'm not opped.")
          when Channel::WHO_LIST_END
            @bot.channel_handler.handle_who_list_end(Regexp.last_match[1])
          when Channel::WHO_LIST_ENTRY
            channel_name, user, host, server, nick, mode, junk, realname = Regexp.last_match.captures
            uhost = "#{nick}!#{user}@#{host}"
            @bot.channel_handler.handle_who_list_entry(nick, uhost, channel_name, mode)
          when Channel::NAMES_LIST_ENTRY
            LOGGER.debug(Regexp.last_match[1])
          when Channel::NAMES_LIST_END
            LOGGER.debug(Regexp.last_match[1])
          when Channel::PART, Channel::PART_NO_REASON
            @bot.channel_handler.dispatch_part(Regexp.last_match.captures)
          when Channel::QUIT, Channel::QUIT_NO_REASON
            @bot.channel_handler.dispatch_quit(Regexp.last_match.captures)
          when Messages::PRIVMSG
            @bot.message_handler.dispatch_privmsg(Regexp.last_match.captures)
          when Messages::NOTICE, Messages::NOTICE_NOPREFIX
            @bot.message_handler.dispatch_notice(Regexp.last_match.captures)
          when Server::MOTD_END, Server::MOTD_ERROR
            LOGGER.info("end of motd, performing autojoin")
            @bot.autojoin_channels
          when Server::MOTD_BEGIN
            LOGGER.info("begin motd")
          when Server::MOTD_ENTRY
            LOGGER.info("motd: #{Regexp.last_match[1]}")
          when Server::PARAMETERS
            if (Regexp.last_match[1] =~ /MODES=(\d+)/)
              @bot.server.max_modes = Regexp.last_match[1]
            end
          when Server::ANY_NUMERIC
            LOGGER.warn("[#{Regexp.last_match[1]}] #{Regexp.last_match[2]}")
          else
            LOGGER.warn("Unhandled server message: #{text}")
        end
      end
    end
  end
end
