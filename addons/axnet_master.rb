require 'yaml'
require 'axial/addon'
require 'axial/axnet/client_handler'

module Axial
  module Addons
    class AxnetMaster < Axial::Addon
      def initialize(bot)
        super

        @name    = 'axnet master'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        @master_thread  = nil
        @connections    = []
        @listener       = nil
        @running        = false
        @port           = 34567
        @cacert         = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet-ca.crt'))
        @key            = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.key'))
        @cert           = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.crt'))

        on_startup  :start_master_thread
      end

      def close_connections()
        @connections.each do |conn|
          conn.close
        end
        @connections = []
      end

      def broadcast(payload)
        LOGGER.debug("broadcasting to #{@connections.count} connections")
        @connections.each do |conn|
          conn.send(payload)
        end
      end

      def stop_master_thread()
        @running = false
        close_connections
        if (!@master_thread.nil?)
          @master_thread.kill
        end
        @master_thread = nil
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
      end

      def listen()
        LOGGER.info("axnet master listening for connections on port #{@port}")
        context = OpenSSL::SSL::SSLContext::new
        context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
        context.cert = OpenSSL::X509::Certificate.new(File.read(@cert))
        context.key = OpenSSL::PKey::RSA.new(File.read(@key))
        context.ca_file = @cacert
        context.ssl_version = :TLSv1_2

        context.ciphers = [
            ["DHE-RSA-AES256-GCM-SHA384", "TLSv1/SSLv3", 256, 256],
        ]

        tcp_listener = TCPServer.new(@port)
        loop do
          begin
            LOGGER.debug("listener accepting more connections on port #{@port}")
            listener = OpenSSL::SSL::SSLServer::new(tcp_listener, context)
            client = listener.accept
            handler = Axial::Axnet::ClientHandler.new(client)
            thread = Thread.new do
              handler.ssl_handshake
              handler.loop
              @connections.delete(handler)
            end
            @connections.push(handler)
          rescue Exception => ex
            LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
            ex.backtrace.each do |i|
              LOGGER.error(i)
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
      end

      def start_master_thread()
        Thread.new do
          while (true)
            broadcast(YAML.dump(@bot.user_list))
            sleep 5
            end
        end
        @running = true
        @master_thread = Thread.new do
          while (@running)
            begin
              listen
            rescue Exception => ex
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            ensure
              sleep 5
            end
          end
        end
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: shutting down connection to master")
        stop_master_thread
      end
    end
  end
end
