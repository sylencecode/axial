module Axial
  module IRCTypes
    class DCCState
      @monitor        = Monitor.new
      @port_monitor   = Monitor.new
      @connections    = {}

      def self.connections()
        return @connections
      end

      def self.monitor()
        return @monitor
      end

      def self.port_monitor()
        return @port_monitor
      end

      def self.broadcast(text, role = :friend)
        @connections.each do |uuid, state_data|
          dcc = state_data[:dcc]
          begin
            if (dcc.user.role >= role)
              dcc.message(text)
            end
          rescue
          end
        end
      end
    end
  end
end

