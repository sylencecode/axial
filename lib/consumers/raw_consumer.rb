require 'consumers/generic_consumer'

module Axial
  module Consumers
    class RawConsumer < GenericConsumer
      def initialize(callback_object, method)
        super
      end

      def consume()
        while (msg = @queue.deq)
          @callback_object.public_send(@method, msg)
        end
      end
    end
  end
end