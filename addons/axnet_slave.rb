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

        @slave_thread     = nil
        @running          = false
        @slave_monitor    = Monitor.new
        @port             = 34567
        @handler          = nil
        @master_address   = 'axial.sylence.org'
        @cacert           = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet-ca.crt'))
        @key              = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.key'))
        @cert             = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.crt'))

        on_startup  :start_slave_thread
        on_reload   :start_slave_thread
        on_axnet    'USERLIST_RESPONSE', :update_user_list
      end

      def update_user_list(handler, command)
        user_list_yaml = command.args.gsub(/\0/, "\n")
        new_user_list = YAML.load(user_list_yaml)
        @slave_monitor.synchronize do
          @bot.axnet_monitor.update_user_list(new_user_list)
        end
        LOGGER.info("downloaded new userlist from #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def stop_slave_thread()
        @running = false
        @handler.close
        @tcp_listener.shutdown
        if (!@slave_thread.nil?)
          @slave_thread.kill
        end
        @master_thread = nil
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
      end

      def client()
        LOGGER.info("connecting to #{@master_address}:#{@port}")
        context = OpenSSL::SSL::SSLContext::new
        context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
        context.cert = OpenSSL::X509::Certificate.new(File.read(@cert))
        context.key = OpenSSL::PKey::RSA.new(File.read(@key))
        context.ca_file = @cacert
        context.ssl_version = :TLSv1_2

        context.ciphers = [
            ["DHE-RSA-AES256-GCM-SHA384", "TLSv1/SSLv3", 256, 256],
        ]

        while (@running)
          tcp_socket = TCPSocket.new(@master_address, @port)
          ssl_socket = OpenSSL::SSL::SSLSocket::new(tcp_socket, context)
          server_socket = ssl_socket.connect
          @handler = Axial::Axnet::SocketHandler.new(@bot, server_socket)
          LOGGER.debug("fetching userlist from #{@handler.remote_cn}")
          @handler.clear_queue
          @handler.send('USERLIST')
          @handler.loop
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
        sleep 5
      end

      def start_slave_thread()
        LOGGER.debug("starting axial slave thread")
        @running = true
        @slave_thread = Thread.new do
          while (@running)
            begin
              client
            rescue Exception => ex
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
              sleep 5
            end
          end
        end
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: shutting down axnet slave connector")
        stop_slave_thread
      end
    end
  end
end
