module Axial
  module Axnet
    class SocketHandler
      attr_reader :socket, :thread, :remote_cn

      def initialize(bot, socket)
        @bot                  = bot
        @remote_cn            = 'unknown'
        @socket               = socket
        @socket.sync_close    = true
        @transmit_consumer    = Consumers::RawConsumer.new(self, :socket_send)
        @thread               = Thread.current
        @monitor              = Monitor.new
        @remote_address       = @socket.to_io.peeraddr[2]
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
        @socket.puts(payload)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def ssl_handshake()
        x509_cert = @socket.context.cert
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

        @remote_cn = x509_cn_fragment[1]
      end

      def close()
        @socket.sysclose
      end

      def loop()
        ssl_handshake
        @transmit_consumer.start
        LOGGER.info("established axnet connection with '#{@remote_cn}' (#{@remote_address})")
        while (text = @socket.gets)
          text.strip!
          @bot.bind_handler.dispatch_axnet_binds(self, text)
        end
        LOGGER.info("closeed axnet connection with '#{@remote_cn}' (#{@remote_address})")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      ensure
        @transmit_consumer.stop
        close
      end
    end
  end
end
