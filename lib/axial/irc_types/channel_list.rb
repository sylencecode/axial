require 'axial/irc_types/channel'

class ChannelListError < StandardError
end

module Axial
  module IRCTypes
    class ChannelList
      def initialize(server_interface)
        @server_interface = server_interface
        @server_interface.channel_list = {}
      end

      def create(channel_name)
        if (@server_interface.channel_list.has_key?(channel_name.downcase))
          raise(ChannelListError, "attempted to create a duplicate of channel '#{channel_name}'")
        end
        channel = IRCTypes::Channel.new(@server_interface, channel_name)
        @server_interface.channel_list[channel_name] = channel
        @server_interface.send_who(channel_name)
        return channel
      end

      def all_channels()
        return @server_interface.channel_list.values
      end

      def has_channel?(channel_or_name)
        key = nil
        if (channel_or_name.is_a?(IRCType::Channel))
          key = channel_or_name.name.downcase
        elsif (channel_or_name.is_a?(String))
          key = channel_or_name.downcase
        end
        return @server_interface.channel_list.has_key?(key)
      end

      def get(channel_name)
        if (@server_interface.channel_list.has_key?(channel_name.downcase))
          channel = @server_interface.channel_list[channel_name.downcase]
          return channel
        else
          raise(ChannelListError, "channel '#{channel_name}' does not exist")
        end
      end

      def delete(channel_or_name)
        key = nil
        if (channel_or_name.is_a?(IRCType::Channel))
          key = channel_or_name.name.downcase
        elsif (channel_or_name.is_a?(String))
          key = channel_or_name.downcase
        end

        if (@server_interface.channel_list.has_key?(key))
          @server_interface.channel_list.delete(key)
        else
          raise(ChannelListError, "attempted to delete non-existent channel '#{channel_name}")
        end
      end

      def clear()
        @server_interface.channel_list.clear
      end
    end
  end
end
