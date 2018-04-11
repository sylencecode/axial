require 'securerandom'
require 'axial/consumers/raw_consumer'

module Axial
  module Axnet
    class SocketHandler
      attr_accessor   :system_info
      attr_reader     :socket, :thread, :local_cn, :remote_cn, :uuid, :established_time, :remote_address

      def initialize(bot, socket)
        @bot                  = bot
        @remote_cn            = 'unknown'
        @local_cn             = 'unknown'
        @socket               = socket
        @socket.sync_close    = true
        @transmit_consumer    = Consumers::RawConsumer.new
        @thread               = Thread.current
        @monitor              = Monitor.new
        @remote_address       = @socket.to_io.peeraddr[2]
        @uuid                 = SecureRandom.uuid
        @system_info          = nil
        @established_time     = Time.now

        @transmit_consumer.register_callback(self, :socket_send)
      end

      def send(payload)
        @transmit_consumer.send(payload)
      rescue Exception => ex
        LOGGER.error("#{self.class} consumer enqueue error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def socket_send(payload)
        @monitor.synchronize do
          @socket.puts(payload)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} socket error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def clear_queue()
        @transmit_consumer.clear
      end

      def ssl_handshake()
        remote_x509_cert = @socket.peer_cert
        remote_x509_array = remote_x509_cert.subject.to_a
        if (remote_x509_array.empty?)
          raise(AxnetError, "No subject info found in certificate: #{remote_x509_cert.inspect}")
        end

        x509_fragments = remote_x509_array.select { |subject_fragment| subject_fragment[0] == 'CN' }.flatten
        if (x509_fragments.empty?)
          raise(AxnetError, "No CN found in #{remote_x509_array.inspect}")
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
        @transmit_consumer.start
        LOGGER.info("established axnet connection to #{@remote_cn} (#{@remote_address})")
        while (text = @socket.gets)
          text.strip!
          @bot.bind_handler.dispatch_axnet_binds(self, text)
        end
        LOGGER.info("closed axnet connection to #{@remote_cn} (#{@remote_address})")
      rescue Exception => ex
        LOGGER.error("#{self.class} loop error: #{ex.class}: #{ex.message}")
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
