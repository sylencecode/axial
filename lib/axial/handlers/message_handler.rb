require 'axial/color'
require 'axial/irc_types/nick'

module Axial
  module Handlers
    class MessageHandler
      def initialize(bot)
        @bot = bot
        @server_interface = @bot.server_interface
      end

      def parse_ctcp(captures)
        ctcp_command, ctcp_args = captures
        ctcp_command.delete!("\u0001")
        ctcp_command.strip!
        ctcp_args.delete!("\u0001")
        ctcp_args.strip!
      end
      private :parse_ctcp

      def dispatch_notice(uhost, dest, text) # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity
        # HACK: notices from implementations like ratbox may not have an initial server prefix
        if (dest.nil? || dest.empty?)
          @bot.server_handler.handle_server_notice(uhost)
        elsif (uhost.casecmp(@bot.server.real_address).zero? || !uhost.include?('!'))
          @bot.server_handler.handle_server_notice(text)
        elsif (dest.start_with?('#'))
          nick_name = uhost.split('!').first
          channel = @server_interface.channel_list.get(dest)
          nick = channel.nick_list.get(nick_name)
          @bot.channel_handler.handle_channel_notice(channel, nick, text)
        else
          nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          if (text =~ /\x01(\S+)(.*)\x01{0,1}/)
            ctcp_command, ctcp_args = parse_ctcp(Regexp.last_match.captures)
            @server_interface.handle_ctcp_reply(nick, ctcp_command, ctcp_args)
          else
            handle_private_notice(nick, text)
          end
        end
      end

      def dispatch_privmsg(uhost, dest, text)
        if (dest.start_with?('#'))
          nick_name = uhost.split('!').first
          channel = @server_interface.channel_list.get(dest)
          nick = channel.nick_list.get(nick_name)
          @bot.channel_handler.handle_channel_message(channel, nick, text)
        else
          nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          handle_private_message(nick, text)
        end
      end

      def handle_private_message(nick, text)
        if (text =~ /\x01(\S+)(.*)\x01{0,1}/)
          ctcp_command, ctcp_args = parse_ctcp(Regexp.last_match.captures)
          @server_interface.handle_ctcp(nick, ctcp_command, ctcp_args)
        else
          dispatched_commands = @bot.bind_handler.dispatch_privmsg_binds(nick, text)
          if (dispatched_commands.any?)
            dispatched_commands.each do |dispatched_command|
              if (dispatched_command[:silent])
                next
              end

              msg  = Color.blue_arrow + Color.cyan(nick.uhost)
              msg += " executed privmsg command: #{text}"
              dcc_broadcast(msg, :director)
              LOGGER.info("privmsg command: #{nick.uhost}: #{text}")
            end
          else
            LOGGER.info("#{nick.name} PRIVMSG: #{text}")
          end
        end
      end

      def handle_private_notice(nick, text)
        LOGGER.info("#{nick.name} NOTICE: #{text}")
      end
    end
  end
end
