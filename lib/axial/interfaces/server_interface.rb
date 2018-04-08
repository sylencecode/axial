require 'axial/irc_types/mode'
require 'axial/irc_types/nick'
require 'axial/irc_types/channel_list'

class ServerInterfaceError < StandardError
end

module Axial
  module Interfaces
    class ServerInterface
      attr_reader     :channel_list, :trying_to_join
      attr_accessor   :myself, :max_modes

      def initialize(bot)
        @bot              = bot
        @channel_list     = IRCTypes::ChannelList.new(self)
        @myself           = IRCTypes::Nick.new(self)
        @trying_to_join   = {}
        @ctcp_throttle    = 2
        @last_ctcp        = Time.now - @ctcp_throttle
        @max_modes        = 4
      end

      def retry_joins()
        @trying_to_join.each do |channel_name, keyword|
          if (keyword.nil? || keyword.empty?)
            join_channel(channel_name)
          else
            join_channel(channel_name, keyword)
          end
        end
      end

      def join_channel(channel_name, password = '')
        if (password.empty?)
          @bot.connection_handler.send_raw("JOIN #{channel_name}")
        else
          @bot.connection_handler.send_raw("JOIN #{channel_name} #{password}")
        end
      end

      def set_channel_mode(channel_name, mode)
        if (mode.is_a?(IRCTypes::Mode))
          mode.to_string_array.each do |mode_string|
            @bot.connection_handler.send_raw("MODE #{channel_name} #{mode_string}")
          end
        else
          if (mode.empty?)
            @bot.connection_handler.send_raw("MODE #{channel_name}")
          else
            @bot.connection_handler.send_raw("MODE #{channel_name} #{mode}")
          end
        end
      end

      def handle_ctcp(nick, ctcp_command, ctcp_args)
        case ctcp_command.strip
          when 'PING'
            send_ctcp_reply(nick, ctcp_command, ctcp_args)
          when 'VERSION'
            send_ctcp_reply(nick, ctcp_command, "#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
          else
          LOGGER.debug("unknown ctcp #{ctcp_command.inspect} request from #{nick.name}: #{ctcp_args}")
        end
      end

      def handle_ctcp_reply(nick, ctcp_command, ctcp_args)
        case ctcp_command
          when 'PING'
            seconds = (Time.now - Time.at(ctcp_args.to_i)).to_f
            LOGGER.debug("ctcp PING reply from #{nick.name}: #{seconds}")
          else
            LOGGER.debug("ctcp #{ctcp_command} reply from #{nick.name}: #{ctcp_args}")
        end
      end

      def send_ctcp(dest, ctcp_command, ctcp_args = '')
        if (ctcp_args.empty?)
          @bot.connection_handler.send_raw("PRIVMSG #{dest.name} :\x01#{ctcp_command}\x01")
        else
          @bot.connection_handler.send_raw("PRIVMSG #{dest.name} :\x01#{ctcp_command} #{ctcp_args}\x01")
        end
      end

      def send_ctcp_reply(dest, ctcp_command, ctcp_args = '')
        if (@last_ctcp + @ctcp_throttle <= Time.now)
          @last_ctcp = Time.now
          if (ctcp_args.empty?)
            @bot.connection_handler.send_raw("NOTICE #{dest.name} :\x01#{ctcp_command}\x01")
          else
            @bot.connection_handler.send_raw("NOTICE #{dest.name} :\x01#{ctcp_command} #{ctcp_args}\x01")
          end
        end
      end

      def send_who(channel_name)
        @bot.connection_handler.send_raw("WHO #{channel_name}")
      end

      def set_topic(channel_name, text)
        @bot.connection_handler.send_raw("TOPIC #{channel_name} :#{text}")
      end

      def send_raw(raw)
        @bot.connection_handler.send_raw(raw)
      end

      def kick(channel_name, nick_name, reason)
        @bot.connection_handler.send_raw("KICK #{channel_name} #{nick_name} :#{reason}")
      end

      def send_private_message(nick_name, text)
        @bot.connection_handler.send_chat("PRIVMSG #{nick_name} :#{text}")
      end

      def send_channel_message(channel_name, text)
        @bot.connection_handler.send_chat("PRIVMSG #{channel_name} :#{text}")
      end
    end
  end
end
