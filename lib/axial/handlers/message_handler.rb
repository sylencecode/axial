require 'axial/irc_types/nick'

module Axial
  module Handlers
    class MessageHandler
      def initialize(bot)
        @bot = bot
      end

      def dispatch_notice(captures)
        uhost, dest, text = captures
        # hack for notices from places like ratbox with no uhost
        if (dest.nil? || dest.empty?)
          @bot.server_handler.handle_server_notice(uhost)
        elsif (uhost.casecmp(@bot.server.address).zero? || !uhost.include?('!'))
          @bot.server_handler.handle_server_notice(text)
        elsif (dest.start_with?("#"))
          if (@bot.server.channel_list.has_key?(dest.downcase))
            channel = @bot.server.channel_list[dest.downcase]
          else
            raise(RuntimeError, "No channel object for #{dest}")
          end
          # use uhost to fetch nick from channel list
          nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)
          @bot.channel_handler.handle_channel_notice(channel, nick, text)
        else
          nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)
          handle_private_notice(nick, text)
        end
      end

      def dispatch_privmsg(captures)
        uhost, dest, text = captures
        if (dest.start_with?("#"))
          if (@bot.server.channel_list.has_key?(dest.downcase))
            channel = @bot.server.channel_list[dest.downcase]
          else
            raise(RuntimeError, "No channel object for #{dest}")
          end
          # use uhost to fetch nick from channel list
          nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)
          @bot.channel_handler.handle_channel_message(channel, nick, text)
        else
          nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)
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

#
#       def handle_privmsg(nick, msg)
#         LOGGER.info("#{nick.name} PRIVMSG: #{msg}")
#         if (msg =~ /exec (.*)/)
#           command = Regexp.last_match[1].strip
#           user_model = Models::User.get_from_nick_object(nick)
#           if (user_model.nil?)
#             nick.message(Constants::ACCESS_DENIED)
#             return
#           end
#           nick.message("sending command: #{command}")
#           send_raw(command)
#         end
#       end
#
