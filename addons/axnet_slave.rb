require 'yaml'
require 'axial/addon'
require 'axial/axnet/socket_handler'

module Axial
  module Addons
    class AxnetSlave < Axial::Addon
      def initialize(bot)
        super

        @name    = 'axnet slave'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        @slave_thread   = nil
        @running        = false
        @port           = 34567
        @cacert         = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet-ca.crt'))
        @key            = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.key'))
        @cert           = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.crt'))

        on_startup  :start_slave_thread
        on_reload   :start_slave_thread
        on_axnet    'USERLIST_RESPONSE', :update_user_list
      end

      def update_user_list(socket, payload)
        yml = YAML.dump(@bot.user_list)
        socket.send(yml)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def close_connections()
        @connections.each do |conn|
          conn.close
        end
        @connections = []
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def broadcast(payload)
        LOGGER.debug("broadcasting to #{@connections.count} connections")
        @connections.each do |conn|
          conn.send(payload)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def stop_master_thread()
        @running = false
        close_connections
        @tcp_listener.shutdown
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

        @tcp_listener = TCPServer.new(@port)
        while (@running)
          begin
            LOGGER.debug("listener accepting more connections on port #{@port}")
            @ssl_listener = OpenSSL::SSL::SSLServer::new(@tcp_listener, context)
            client_socket = @ssl_listener.accept
            handler = Axial::Axnet::SocketHandler.new(@bot, client_socket)
            Thread.new do
              begin
                handler.loop
                @connections.delete(handler)
              rescue Exception => ex
                LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                ex.backtrace.each do |i|
                  LOGGER.error(i)
                end
              end
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
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def start_master_thread()
        LOGGER.debug("starting axial master thread")
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
            end
          end
        end
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: shutting down axnet master listener")
        stop_master_thread
      end
    end
  end
end
