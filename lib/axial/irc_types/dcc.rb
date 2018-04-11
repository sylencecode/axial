module Axial
  module IRCTypes
    class DCC
      attr_accessor :user, :socket
      attr_writer   :state_data

      def initialize(server_interface)
        @server_interface = server_interface
        @user       = nil
        @socket     = nil
        @state_data = nil
      end

      def close()
        @socket.close
      end

      def status()
        return @state_data[:status]
      end

      def status=(status)
        @state_data[:status] = status
      end

      def remote_ip()
        return @state_data[:remote_ip]
      end

      def message(text)
        @socket.puts(text)
      end

      def self.from_socket(state_data, server_interface, socket, user)
        if (socket.nil? || user.nil?)
          return nil
        end

        dcc             = new(server_interface)
        dcc.state_data  = state_data
        dcc.socket      = socket
        dcc.user        = user
        return dcc
      end
    end
  end
end
