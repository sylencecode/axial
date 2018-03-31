require 'yaml'
require 'axial/addon'
require 'axial/axnet/socket_handler'
require 'axial/axnet/user'

module Axial
  module Addons
    class AxnetMaster < Axial::Addon
      def initialize(bot)
        super

        @name    = 'axnet master'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        @last_uhost             = @bot.server_interface.myself.uhost
        @uhost_timer            = nil
        @refresh_timer          = nil
        @master_thread          = nil
        @handlers               = {}
        @tcp_listener           = nil
        @ssl_listener           = nil
        @running                = false
        @refresh_timer          = nil
        @handler_monitor        = Monitor.new
        @port                   = 34567
        @cacert                 = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet-ca.crt'))
        @key                    = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.key'))
        @cert                   = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.crt'))
        @bot.local_cn           = get_local_cn
        @bot_user               = Axnet::User.new

        on_startup                        :start_master_threads
        on_reload                         :start_master_threads

        on_axnet              'BANLIST',  :send_ban_list
        on_axnet             'BOT_AUTH',  :update_bot_list
        on_axnet             'USERLIST',  :send_user_list

        on_dcc              'broadcast',  :handle_broadcast
        on_dcc                  'axnet',  :handle_axnet_command
        on_dcc             'connstatus',  :display_conn_status

        @bot.axnet.register_transmitter(self, :broadcast)
        @bot.axnet.register_relay(self, :relay)
      end

      def display_conn_status(dcc, command)
        if (@handlers.count == 0)
          dcc.message("no bots connected.")
        end
        @handlers.each do |uuid, handler|
          dcc.message("status for #{uuid} (#{handler.remote_cn})")
          dcc.message(handler.socket.inspect)
          dcc.message(handler.thread.inspect)
        end
      end

      def update_bot_list(handler, command)
        bot_yaml = command.args.gsub(/\0/, "\n")
        new_bot = YAML.load(bot_yaml)
        LOGGER.debug(new_bot.inspect)
        LOGGER.info("new bot online: #{new_bot.pretty_name}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def transmit_bot_list()
        @bot_user.name          = @bot.local_cn
        @bot_user.pretty_name   = @bot.local_cn
        @bot_user.role          = 'bot'
        @bot_user.id            = 0

        if (!@server_interface.myself.uhost.empty?)
          @bot_user.masks       = [ MaskUtils.ensure_wildcard(@server_interface.myself.uhost) ]
        end

        serialized_yaml         = YAML.dump(@bot.bot_list).gsub(/\n/, "\0")
        @bot.axnet.transmit_to_axnet("BOTS #{serialized_yaml}")
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

      def handle_broadcast(dcc, command)
        @bot.axnet.transmit_to_axnet(command.args)
      end

      def send_help(dcc)
        dcc.message("try axnet reload or axnet list")
      end

      def receive_pong(handler, text)
        LOGGER.debug("PONG from #{handler.uuid} (#{handler.remote_cn})")
      end
      
      def handle_axnet_command(dcc, command)
        begin
          if (command.args.strip.empty?)
            send_help(dcc)
            return
          end

          case (command.args.strip)
            when /^list$/i, /^list\s+/i
              list_axnet_connections(dcc)
            when /^reload$/i, /^stop\s+/i
              reload_axnet(dcc)
            else
              send_help(dcc)
          end
        rescue Exception => ex
          dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def list_axnet_connections(dcc)
        bots = []
        @handler_monitor.synchronize do
          bots = @handlers.values.collect{ |handler| handler.remote_cn }
        end
        if (bots.empty?)
          dcc.message("no axnet nodes connected.")
        else
          dcc.message("connected axnet nodes: #{bots.join(', ')}")
        end
      end

      def reload_axnet(dcc)
        dcc.message("#{dcc.user.pretty_name} issuing orders to axnet nodes to update and reload the axial codebase.")
        @bot.axnet.transmit_to_axnet('RELOAD_AXNET')
        @bot.git_pull
        @bot.reload_axnet
        @bot.reload_addons
      end

      def send_user_list(handler, command)
        LOGGER.debug("user list requested from #{handler.remote_cn}")
        user_list_yaml = YAML.dump(@bot.user_list).gsub(/\n/, "\0")
        handler.send('USERLIST_RESPONSE ' + user_list_yaml)
        LOGGER.debug("sent user list to #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def send_ban_list(handler, command)
        LOGGER.debug("ban list requested from #{handler.remote_cn}")
        ban_list_yaml = YAML.dump(@bot.ban_list).gsub(/\n/, "\0")
        handler.send('BANLIST_RESPONSE ' + ban_list_yaml)
        LOGGER.debug("sent ban list to #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def close_connections()
        @handlers.each do |uuid, handler|
          handler.close
        end
        @handlers = {}
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def broadcast(payload)
        LOGGER.debug("broadcasting to #{@handlers.count} connections")
        @handlers.each do |uuid, handler|
          handler.send(payload)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def relay(exclude_handler, text)
        if (@handlers.count < 2)
          return
        end

        LOGGER.debug("relaying to #{@handlers.count - 1} connections")
        @handlers.each do |uuid, handler|
          if (uuid == exclude_handler.uuid)
            next
          else
            handler.send(text)
          end
        end
      end

      def stop_master_threads()
        @running = false
        close_connections
        if (!@tcp_listener.nil?)
          @tcp_listener.shutdown
        end
        if (!@master_thread.nil?)
          @master_thread.kill
        end
        @master_thread = nil
        @bot.timer.delete(@refresh_timer)
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

        begin
          @tcp_listener = TCPServer.new(@port)
        rescue Errno::EADDRINUSE => ex
          LOGGER.error("axnet master can't bind to port #{@port}, it is already in use.")
          @running = false
        end
        while (@running)
          begin
            @ssl_listener = OpenSSL::SSL::SSLServer::new(@tcp_listener, context)
            client_socket = @ssl_listener.accept
            handler = Axial::Axnet::SocketHandler.new(@bot, client_socket)
            Thread.new(handler) do |handler|
              begin
                @handler_monitor.synchronize do
                  @bot.bind_handler.dispatch_axnet_connect_binds(handler)
                end
                handler.loop
                @handler_monitor.synchronize do
                  @bot.bind_handler.dispatch_axnet_disconnect_binds(handler)
                  LOGGER.debug("deleting handler #{handler.uuid} (#{handler.remote_cn})")
                  @handlers.delete(handler.uuid)
                  LOGGER.debug("(#{handler.remote_cn} disconnected (#{handler.uuid})")
                end
              rescue Exception => ex
                LOGGER.warn("error close for #{handler.remote_cn} (#{handler.uuid}")
                ex.backtrace.each do |i|
                  LOGGER.error(i)
                end
                @handler_monitor.synchronize do
                  @bot.bind_handler.dispatch_axnet_disconnect_binds(handler)
                  @handlers.delete(handler.uuid)
                end
              end
            end
            @handler_monitor.synchronize do
              @handlers[handler.uuid] = handler
            end
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

      def start_master_threads()
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
        @refresh_timer = @bot.timer.every_3_seconds(self, :refresh_axnet)
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: shutting down axnet master listener")
        stop_master_threads
      end
    end
  end
end
