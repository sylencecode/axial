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
      end
    end
  end
end