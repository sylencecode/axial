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
        @version = '1.1.0'

        @slave_thread     = nil
        @announce_timer   = nil
        @running          = false
        @port             = 34567
        @handler          = nil
        @master_address   = 'axial.sylence.org'
        @cacert           = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet-ca.crt'))
        @key              = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.key'))
        @cert             = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.crt'))

        on_startup                        :start_slave_thread
        on_reload                         :start_slave_thread
        on_axnet_connect                  :axnet_login
        on_axnet_disconnect               :axnet_disconnect
        on_axnet              'BOT_ADD',  :add_bot_user
        on_axnet           'BOT_REMOVE',  :remove_bot_user
        on_axnet    'USERLIST_RESPONSE',  :update_user_list
        on_axnet     'BANLIST_RESPONSE',  :update_ban_list
        on_axnet         'RELOAD_AXNET',  :reload_axnet
        on_channel        '?connstatus',  :display_conn_status

        @bot.axnet.register_transmitter(self, :send)
      end

      def axnet_disconnect(handler)
        LOGGER.warn("axnet: lost connection to #{handler.remote_cn}")
      end

      def display_conn_status(channel, nick, command)
        user = @bot.user_list.get_from_nick_object(nick)
        if (user.nil? || !user.director?)
          return
        end
        LOGGER.info("status for #{@handler.uuid} (#{@handler.remote_cn})")
        LOGGER.info(@handler.socket.inspect)
        LOGGER.info(@handler.thread.inspect)
      end

      def send(text)
        if (!@handler.nil?)
          @handler.send(text)
        end
      end

      def refresh_axnet()
        #LOGGER.debug('ping')
      end

      def axnet_login(handler)
        @handler.send('USERLIST')
        @handler.send('BANLIST')
        refresh_axnet
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
        @bot.axnet.update_user_list(new_user_list)
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
        @bot.axnet.update_ban_list(new_ban_list)
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
        @bot.timer.delete(@announce_timer)
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
            @bot.bind_handler.dispatch_axnet_connect_binds(@handler)
            @handler.clear_queue
            @handler.loop
            @bot.bind_handler.dispatch_axnet_disconnect_binds(@handler)
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
        @announce_timer = @bot.timer.every_3_seconds(self, :refresh_axnet)
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
