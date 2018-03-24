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
        @port             = 34567
        @handler          = nil
        @master_address   = 'axial.sylence.org'
        @cacert           = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet-ca.crt'))
        @key              = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.key'))
        @cert             = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.crt'))

        on_startup                        :start_slave_thread
        on_reload                         :start_slave_thread
        on_axnet    'PING',               :pong
        on_axnet    'USERLIST_RESPONSE',  :update_user_list
        on_axnet     'BANLIST_RESPONSE',  :update_ban_list
        on_axnet    'RELOAD_AXNET',       :reload_axnet
        on_channel  '?connstatus',        :display_conn_status

        @bot.axnet_interface.register_transmitter(self, :send)
      end

      def display_conn_status(channel, nick, command)
        user = @bot.user_list.get_from_nick_object(nick)
        if (user.nil? || !user.director?)
          return
        end
        LOGGER.info("status for #{@handler.id} (#{@handler.remote_cn})")
        LOGGER.info(@handler.socket.inspect)
        LOGGER.info(@handler.thread.inspect)
      end

      def send(text)
        @handler.send(text)
      end

      def pong(handler, command)
        @bot.axnet_interface.transmit_to_axnet('PONG')
      end

      def reload_axnet(handler, command)
        LOGGER.info("axnet reload request from #{handler.remote_cn}.")
        @bot.git_pull
        @bot.reload_axnet
        @bot.reload_addons
        LOGGER.info("axnet reload complete.")
      end

      def update_user_list(handler, command)
        user_list_yaml = command.args.gsub(/\0/, "\n")
        new_user_list = YAML.load(user_list_yaml)
        @bot.axnet_interface.update_user_list(new_user_list)
        LOGGER.info("successfully downloaded new userlist from #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_ban_list(handler, command)
        ban_list_yaml = command.args.gsub(/\0/, "\n")
        new_ban_list = YAML.load(ban_list_yaml)
        @bot.axnet_interface.update_ban_list(new_ban_list)
        LOGGER.info("successfully downloaded new banlist from #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def stop_slave_thread()
        LOGGER.debug("slave thread exiting")
        @running = false
        @handler.close
        if (!@slave_thread.nil?)
          @slave_thread.kill
        end
        @slave_thread = nil
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
          begin
            tcp_socket = TCPSocket.new(@master_address, @port)
            ssl_socket = OpenSSL::SSL::SSLSocket::new(tcp_socket, context)
            server_socket = ssl_socket.connect
            @handler = Axial::Axnet::SocketHandler.new(@bot, server_socket)
            LOGGER.info("retrieving userlist from axnet...")
            @handler.clear_queue
            @handler.send('USERLIST')
            @handler.loop
          rescue Errno::ECONNREFUSED
            LOGGER.info("could not connect to #{@master_address}:#{@port} - connection refused")
            sleep 15
          rescue Exception => ex
            LOGGER.error("#{self.class} slave connection error: #{ex.class}: #{ex.message}")
            ex.backtrace.each do |i|
              LOGGER.error(i)
            end
            sleep 15
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} slave SSL context initialization error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
        LOGGER.error("retry executes in 5 seconds...")
        sleep 5
        retry
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
        LOGGER.warn("#{self.class}: shutting down axnet slave connector")
        stop_slave_thread
      end
    end
  end
end
