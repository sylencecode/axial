module Axial
  class Server
    attr_reader :address, :port, :password, :timeout

    def initialize(address, port, ssl, password, timeout)
      @address = address
      @password = password
      @port = 6667
      @ssl = ssl
      @timeout = timeout
    end

    def ssl?()
      return @ssl
    end
  end
end