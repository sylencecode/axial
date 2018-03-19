require 'axial/irc_types/mode'

class ChannelError < StandardError
end

module Axial
  module IRCTypes
    class Channel
      attr_reader :name
      attr_accessor :password, :nick_list, :topic

      def initialize(server_interface, channel_name)
        @server_interface = server_interface
        @name = channel_name
        @topic = ""
        @mode = IRCTypes::Mode.new
        @nick_list = {}
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
        @server_interface.set_channel_mode(@name, mode)
       end

      def message(text)
        @server_interface.send_channel_message(@name, text)
      end
    end
  end
end
