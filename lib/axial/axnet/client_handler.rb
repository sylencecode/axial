module Axial
  module Axnet
    class ClientHandler
      attr_reader :client, :thread, :monitor

      def initialize(client)
        @client               = client
        @client.sync_close    = true
        @transmit_consumer    = Consumers::RawConsumer.new(self, :socket_send)
        @thread               = Thread.current
        @monitor              = Monitor.new
      end

      def send(payload)
        @transmit_consumer.send(payload)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def socket_send(payload)
        @client.puts(payload)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def ssl_handshake()
        x509_cert = @client.context.cert
        x509_array = x509_cert.subject.to_a
        if (x509_array.count == 0)
          raise(AxnetError, "No subject info found in certificate: #{x509_cert.inspect}")
        end

        x509_fragments = x509_array.select{|subject_fragment| subject_fragment[0] == 'CN'}.flatten
        if (x509_fragments.count == 0)
          raise(AxnetError, "No CN found in #{x509_array.inspect}")
        end

        x509_cn_fragment = x509_fragments.flatten
        if (x509_cn_fragment.count < 3)
          raise(AxnetError, "CN fragment appears to be corrupt: #{x509_cn_fragment.inspect}")
        end

        user_cn = x509_cn_fragment[1]
        @cn = user_cn
      end

      def close()
        @client.sysclose
        @thread.kill
      end

      def loop()
        ssl_handshake
        @transmit_consumer.start
        LOGGER.info("axnet connection established to '#{@cn}'")
        while (line = @client.gets)
          line.strip!
          puts line.inspect
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      ensure
        @transmit_consumer.stop
        @client.sysclose
        @thread.kill
      end
    end
  end
end
