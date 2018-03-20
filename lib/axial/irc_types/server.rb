module Axial
  module IRCTypes
    class Server
      attr_accessor :address, :max_modes, :real_address
      attr_reader   :port, :password, :timeout

      def initialize(address, port, ssl, password, timeout)
        @address = address
        @password = password
        @port = port
        @ssl = ssl
        @timeout = timeout
        @max_modes = 4
        @real_address = address
      end

      def ssl?()
        return @ssl
      end
    end
  end
end
