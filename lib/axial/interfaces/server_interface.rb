require 'axial/irc_types/mode'
require 'axial/irc_types/nick'
require 'axial/irc_types/channel_list'

class ServerInterfaceError < StandardError
end

module Axial
  module Interfaces
    class ServerInterface
      attr_reader     :channel_list, :trying_to_join
      attr_accessor   :myself, :max_modes, :max_nick_length

      def initialize(bot)
        @bot                    = bot
        @channel_list           = IRCTypes::ChannelList.new(self)
        @myself                 = IRCTypes::Nick.new(self)
        @trying_to_join         = {}
        @ctcp_throttle          = 2
        @last_ctcp              = Time.now - @ctcp_throttle
        @max_modes              = 4
        @max_nick_length        = 9
        @nick_shuffle_attempts  = 0
      end

      def set_invisible()
        @bot.connection_handler.send_raw("MODE #{@bot.real_nick} #{@bot.server.user_mode}")
      end

      def whois_myself()
        @bot.connection_handler.send_raw("WHOIS #{@bot.real_nick}")
      end

      def cancel_pending_joins()
        @trying_to_join.clear
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

      def part_channel(channel_or_name)
        if (channel_or_name.is_a?(IRCTypes::Channel))
          channel_name = channel_or_name.name.downcase
        elsif (channel_or_name.is_a?(String))
          channel_name = channel_or_name.downcase
        end
        @bot.connection_handler.send_raw("PART #{channel_name}")
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
            if (@bot.custom_ctcp_version_reply.empty?)
              send_ctcp_reply(nick, ctcp_command, "#{Constants::AXIAL_LOGO} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
            else
              send_ctcp_reply(nick, ctcp_command, @bot.custom_ctcp_version_reply)
            end
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

      def send_ison()
        LOGGER.debug('ison timer called')
        if (!@bot.real_nick.casecmp(@bot.nick).zero?)
          @bot.connection_handler.send_raw("ISON #{@bot.nick}")
        else
          LOGGER.warn('regain_nick timer called, but bot already has the right nick')
        end
      end

      def rotate_nick_characters(nick_name)
        char_array = nick_name.scan(/\S/)
        new_char = char_array.shift
        char_array.push(new_char)
        new_nick_name = char_array.join('')
        return (new_nick_name)
      end

      def nick_in_use(nick_name, type = :in_use)
        if (!@bot.connection_handler.regaining_nick)
          if (type == :erroneous)
            LOGGER.warn("nick #{nick_name} is invalid. tryin  g a permutation.")
          else
            LOGGER.warn("nick #{nick_name} already in use. trying a permutation.")
          end

          sleep 1
          @nick_shuffle_attempts += 1
          if (@nick_shuffle_attempts < @bot.trying_nick.length)
            @bot.trying_nick = rotate_nick_characters(nick_name)
            @bot.connection_handler.try_nick
          else
            LOGGER.warn('unable to secure a valid nickname on the server. giving up.')
          end
        end
      end
    end
  end
end
