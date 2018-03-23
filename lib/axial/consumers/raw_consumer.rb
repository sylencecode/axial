require 'axial/consumers/generic_consumer'

module Axial
  module Consumers
    class RawConsumer < GenericConsumer
      def initialize()
        super
      end

      def consume()
        while (msg = @queue.deq)
          @transmitter_object.public_send(@transmitter_method, msg)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
