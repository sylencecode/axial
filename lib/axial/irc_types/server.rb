module Axial
  module IRCTypes
    class Server
      attr_accessor :address, :modes
      attr_reader   :port, :password, :timeout, :channel_list

      def initialize(address, port, ssl, password, timeout)
        @address = address
        @password = password
        @port = 6667
        @ssl = ssl
        @timeout = timeout
        @channel_list = {}
        @modes = 4
      end

      def ssl?()
        return @ssl
      end
    end
  end
end