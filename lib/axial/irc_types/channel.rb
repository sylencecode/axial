require 'axial/irc_types/nick_list'
require 'axial/irc_types/mode'

class ChannelError < StandardError
end

module Axial
  module IRCTypes
    class Channel
      attr_reader :name, :monitor
      attr_accessor :password, :nick_list, :opped, :voiced

      def initialize(server_interface, channel_name)
        @server_interface = server_interface
        @name = channel_name
        @topic = ""
        @mode = IRCTypes::Mode.new
        @nick_list = IRCTypes::NickList.new(@server_interface)
        @synced = false
        @opped = false
        @voiced = false
      end

      def set_topic(topic)
        @server_interface.set_channel_topic(@name, topic)
      end

      def opped?()
        return @opped
      end

      def voiced?()
        return @voiced
      end

      def op(nick)
        mode = IRCTypes::Mode.new
        mode.op(nick.name)
        set_mode(mode)
      end

      def voice(nick)
        mode = IRCTypes::Mode.new
        mode.voice(nick.name)
        set_mode(mode)
      end

      def set_mode(mode)
        if (!mode.is_a?(Axial::IRCTypes::Mode))
          raise(ChannelError, "#{self.class}.set_channel_mode must be invoked with an Axial::IRCTypes::Mode object.")
        end
        if (opped?)
          @server_interface.set_channel_mode(@name, mode)
        else
          LOGGER.info("Tried to set channel mode #{mode.to_string_array.inspect} on #{channel}, but I am not an op.")
        end
      end

      def message(text)
        @server_interface.send_channel_message(@name, text)
      end

      def kick(nick, reason)
        if (reason.nil? || reason.empty?)
          reason = "kicked"
        end
        @server_interface.kick(@name, nick.name, reason)
      end

      # placeholder methods for possible eventual method blocking until the channel has been synced
      def sync_complete()
        LOGGER.debug("#{self.name} sync completed")
        @synced = true
      end

      def synced?()
        return @synced
      end

      def sync_begin()
        LOGGER.debug("#{self.name} sync beginning")
        @synced = false
      end
    end
  end
end
