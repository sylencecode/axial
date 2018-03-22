module Axial
  module Consumers
    class ConsumerError < StandardError
    end

    class GenericConsumer
      attr_reader :publisher

      def initialize(callback_object, method)
        @callback_object = callback_object
        @queue = Queue.new
        @thread = nil
        @method = method.to_sym
      end

      def start()
        if (!@callback_object.respond_to?(@method))
          raise(ConsumerError, "Class #{@callback_object.class} does not respond to method #{@method}")
        end

        @queue.clear
        @thread = Thread.new do
          begin
            consume
          rescue Exception => ex
            LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message.inspect}")
            ex.backtrace.each do |i|
              LOGGER.error(i)
            end
          end
        end
      end

      def consume()
        raise(RuntimeError, "No 'consume' method defined for #{self.class}")
      end

      def stop()
        @queue.clear
        if (!@thread.nil?)
          @thread.kill
        end
        @thread = nil
      end

      def send(msg)
        @queue.enq(msg)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
