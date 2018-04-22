module Axial
  module Consumers
    class ConsumerError < StandardError
    end

    class GenericConsumer
      attr_reader :publisher

      def initialize()
        @transmitter_object   = nil
        @mtransmitter_ethod   = nil
        @queue                = Queue.new
        @thread               = nil
      end

      def clear()
        @queue.clear
      end

      def register_callback(callback_object, callback_method)
        if (!callback_object.respond_to?(callback_method))
          raise(ConsumerError, "Class #{@transmitter_object.class} does not respond to method #{@method}")
        end
        @transmitter_object = callback_object
        @transmitter_method = callback_method
      end

      def start()
        if (@transmitter_object.nil? || @transmitter_method.nil?)
          raise(ConsumerError, 'No callback object/method registered.')
        end

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
        raise("No 'consume' method defined for #{self.class}")
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
