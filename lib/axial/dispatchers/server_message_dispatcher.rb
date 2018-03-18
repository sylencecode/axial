require 'axial/handlers/patterns'
require 'axial/dispatchers/numeric_dispatcher'

module Axial
  module Dispatchers
    class ServerMessageDispatcher
      include Handlers::Patterns

      def initialize(bot)
        @bot = bot
        @numeric_dispatcher = NumericDispatcher.new(@bot)
      end

      def dispatch(text)
        case text
          when Channel::JOIN
            @bot.channel_handler.dispatch_join(Regexp.last_match.captures)
          when Channel::MODE
            @bot.channel_handler.dispatch_mode(Regexp.last_match.captures)
          when Messages::PRIVMSG
            @bot.message_handler.dispatch_privmsg(Regexp.last_match.captures)
          when Messages::NOTICE, Messages::NOTICE_NOPREFIX
            @bot.message_handler.dispatch_notice(Regexp.last_match.captures)
          when Server::NUMERIC
            @numeric_dispatcher.dispatch_numeric(Regexp.last_match.captures)
          when Channel::PART, Channel::PART_NO_REASON
            @bot.channel_handler.dispatch_part(Regexp.last_match.captures)
          when Channel::QUIT, Channel::QUIT_NO_REASON
            @bot.channel_handler.dispatch_quit(Regexp.last_match.captures)
          else
            LOGGER.warn("Unhandled from server: #{text}")
        end
      end
    end
  end
end