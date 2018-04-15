module Axial
  module IRCTypes
    class Server
      attr_accessor :address, :real_address
      attr_reader   :port, :password, :reconnect_delay
      attr_writer   :connected, :ssl

      def initialize(address, port, ssl, password, reconnect_delay)
        @address            = address
        @password           = password
        @port               = port.to_i
        @ssl                = ssl
        @reconnect_delay    = reconnect_delay
        @real_address       = address
        @connected          = false
      end

      def connected?()
        return @connected
      end

      def ssl?()
        return @ssl
      end
    end
  end
end
