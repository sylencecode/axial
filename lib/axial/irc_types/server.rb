module Axial
  module IRCTypes
    class Server
      attr_accessor :address, :real_address
      attr_reader   :port, :password, :timeout
      attr_writer   :connected, :ssl

      def initialize(address, port, ssl, password, timeout)
        @address        = address
        @password       = password
        @port           = port
        @ssl            = ssl
        @timeout        = timeout
        @real_address   = address
        @connected      = false
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
