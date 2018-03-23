require 'axial/consumers/generic_consumer'

module Axial
  module Consumers
    class ChatConsumer < GenericConsumer
      def initialize()
        super
      end

      def consume()
        while (msg = @queue.deq)
          @transmitter_object.public_send(@transmitter_method, msg)
          sleep 0.5
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
