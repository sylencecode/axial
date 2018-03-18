module Axial
  module IRCTypes
    class Channel
      attr_reader :name
      attr_accessor :password, :mode, :topic

      def initialize(server_interface, channel_name)
        @server_interface = server_interface
        @name = channel_name
        @mode = ""
        @topic = ""
      end

      def op(nick)
        @server_interface.set_channel_mode(@name, "+o #{nick.name}")
      end

      def voice(nick)
        @server_interface.set_channel_mode(@name, "+v #{nick.name}")
      end

      def message(text)
        @server_interface.send_channel_message(@name, text)
      end
    end
  end
end
