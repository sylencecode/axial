require 'yaml'
require 'axial/addon'
require 'axial/axnet/socket_handler'
require 'axial/axnet/user'

module Axial
  module Addons
    class AxnetSlave < Axial::Addon
      def initialize(bot)
        super

        @name    = 'axnet slave'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        @last_uhost                       = myself.uhost
        @uhost_timer                      = nil
        @refresh_timer                    = nil
        @slave_thread                     = nil
        @running                          = false
        @port                             = 34567
        @handler                          = nil
        @master_address                   = 'axial.sylence.org'
        @cacert                           = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet-ca.crt'))
        @key                              = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.key'))
        @cert                             = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.crt'))
        @bot.local_cn                     = get_local_cn
        @bot_user                         = Axnet::User.new

        if (axnet.master?)
          raise(AddonError, "attempted to load both the axnet master and slave addons")
        end

        on_startup                        :start_slave_thread
        on_reload                         :start_slave_thread
        on_axnet_connect                  :axnet_login
        on_axnet_disconnect               :axnet_disconnect
        on_axnet    'USERLIST_RESPONSE',  :update_user_list
        on_axnet                 'BOTS',  :update_bot_list
        on_axnet     'BANLIST_RESPONSE',  :update_ban_list
        on_axnet         'RELOAD_AXNET',  :reload_axnet

        on_channel               'ping',  :pong_channel

        axnet.register_transmitter(self, :send)
      end

      def pong_channel(channel, nick, command)
        user = user_list.get_from_nick_object(nick)
        if (!user.nil? && user.director?)
          channel.message("pong")
        end
      end

      def check_for_uhost_change()
        if (!myself.uhost.casecmp(@last_uhost).zero?)
          LOGGER.debug("uhost changed from #{@last_uhost} to #{myself.uhost}")
          @last_uhost = myself.uhost
          auth_to_axnet
        end
      end

      def auth_to_axnet()
        @bot_user.name          = @bot.local_cn
        @bot_user.pretty_name   = @bot.local_cn
        @bot_user.role_name          = 'bot'
        @bot_user.id            = 0

        if (!myself.uhost.empty?)
          @bot_user.masks       = [ MaskUtils.ensure_wildcard(myself.uhost) ]
        end

        serialized_yaml         = YAML.dump(@bot_user).gsub(/\n/, "\0")
        axnet.send('BOT_AUTH ' + serialized_yaml)
      end

      def update_bot_list(handler, command)
        bot_list_yaml = command.args.gsub(/\0/, "\n")
        new_bot_list = YAML.load(bot_list_yaml)
        bot_list.reload(new_bot_list)
        LOGGER.info("successfully downloaded new botlist from #{@handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
    end

      def axnet_disconnect(handler)
        LOGGER.warn("axnet: lost connection to #{handler.remote_cn}")
      end

      def send(text)
        if (!@handler.nil?)
          @handler.send(text)
        end
      end

      def axnet_login(handler)
        auth_to_axnet
        @handler.send('USERLIST')
        @handler.send('BANLIST')
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
        axnet.update_user_list(new_user_list)
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
        axnet.update_ban_list(new_ban_list)
        LOGGER.info("successfully downloaded new banlist from #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def get_local_cn()
        local_x509_cert = OpenSSL::X509::Certificate.new(File.read(@cert))
        local_x509_array = local_x509_cert.subject.to_a
        if (local_x509_array.empty?)
          raise(AxnetError, "No subject info found in certificate: #{local_x509_cert.inspect}")
        end

        local_x509_fragments = local_x509_array.select{ |subject_fragment| subject_fragment[0] == 'CN' }.flatten
        if (local_x509_fragments.empty?)
          raise(AxnetError, "No CN found in #{local_x509_array.inspect}")
        end

        local_x509_cn_fragment = local_x509_fragments.flatten
        if (local_x509_cn_fragment.count < 3)
          raise(AxnetError, "CN fragment appears to be corrupt: #{local_x509_cn_fragment.inspect}")
        end

        return local_x509_cn_fragment[1]
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
            @handler = Axnet::SocketHandler.new(@bot, server_socket)
            @handler.ssl_handshake
            bind_handler.dispatch_axnet_connect_binds(@handler)
            @handler.clear_queue
            @handler.loop
            bind_handler.dispatch_axnet_disconnect_binds(@handler)
            LOGGER.error("lost connection to #{@handler.remote_cn}")
            sleep 15
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

        @running        = true
        @refresh_timer  = timer.every_minute(self, :auth_to_axnet)
        @uhost_timer    = timer.every_second(self, :check_for_uhost_change)

        @slave_thread   = Thread.new do
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

      def stop_slave_thread()
        LOGGER.debug("slave thread exiting")
        @running = false
        @handler.close
        if (!@slave_thread.nil?)
          @slave_thread.kill
        end
        @slave_thread = nil
        timer.delete(@refresh_timer)
        timer.delete(@uhost_timer)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: shutting down axnet slave connector")
        stop_slave_thread
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
