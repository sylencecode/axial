require 'axial/consumers/generic_consumer'

module Axial
  module Consumers
    class ChatConsumer < GenericConsumer
      def initialize(callback_object, method)
        super
      end

      def consume()
        while (msg = @queue.deq)
          @callback_object.public_send(@method, msg)
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
