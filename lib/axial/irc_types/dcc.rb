module Axial
  module IRCTypes
    class DCC
      attr_accessor :user, :socket
      def initialize(server_interface)
        @server_interface = server_interface
        @user = nil
        @socket = nil
      end

      def message(text)
        @socket.puts(text)
      end

      def self.from_socket(server_interface, socket, user)
        if (socket.nil? || user.nil?)
          return nil
        end

        dcc         = new(server_interface)
        dcc.socket  = socket
        dcc.user    = user
        return dcc
      end
    end
  end
end
