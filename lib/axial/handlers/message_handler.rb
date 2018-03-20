require 'axial/irc_types/nick'

module Axial
  module Handlers
    class MessageHandler
      def initialize(bot)
        @bot = bot
        @server_interface = @bot.server_interface
        @channel_list = @server_interface.channel_list
      end

      def dispatch_notice(uhost, dest, text)
        # hack for notices from implementations like ratbox that may not have an initial server prefix
        if (dest.nil? || dest.empty?)
          @bot.server_handler.handle_server_notice(uhost)
        elsif (uhost.casecmp(@bot.server.real_address).zero? || !uhost.include?('!'))
          @bot.server_handler.handle_server_notice(text)
        elsif (dest.start_with?("#"))
          nick_name = uhost.split('!').first
          channel = @channel_list.get(dest)
          nick = channel.nick_list.get(nick_name)
          @bot.channel_handler.handle_channel_notice(channel, nick, text)
        else
          nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          handle_private_notice(nick, text)
        end
      end

      def dispatch_privmsg(uhost, dest, text)
        if (dest.start_with?("#"))
          nick_name = uhost.split('!').first
          channel = @channel_list.get(dest)
          nick = channel.nick_list.get(nick_name)
          @bot.channel_handler.handle_channel_message(channel, nick, text)
        else
          nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          handle_private_message(nick, text)
        end
      end

      def handle_private_message(nick, text)
        @bot.bind_handler.dispatch_privmsg_binds(nick, text)
        LOGGER.info("#{nick.name} PRIVMSG: #{text}")
      end

      def handle_private_notice(nick, text)
        LOGGER.info("#{nick.name} NOTICE: #{text}")
      end
    end
  end
end
