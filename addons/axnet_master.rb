require 'yaml'
require 'axial/addon'
require 'axial/axnet/socket_handler'

module Axial
  module Addons
    class AxnetMaster < Axial::Addon
      def initialize(bot)
        super

        @name    = 'axnet master'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        @master_thread  = nil
        @handlers       = []
        @tcp_listener   = nil
        @ssl_listener   = nil
        @running        = false
        @port           = 34567
        @cacert         = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet-ca.crt'))
        @key            = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.key'))
        @cert           = File.expand_path(File.join(File.dirname(__FILE__), '..', 'certs', 'axnet.crt'))

        on_startup                  :start_master_thread
        on_reload                   :start_master_thread
        on_channel  '?broadcast',   :handle_channel_broadcast
        on_channel      '?axnet',   :handle_axnet_command
        on_axnet     'USERLIST',    :send_user_list
        on_axnet           'OP',    :op_and_repeat
        on_axnet         'PONG',    :receive_pong

        @bot.axnet_interface.register_transmitter(self, :broadcast)
      end

      def handle_channel_broadcast(nick, channel, command)
        @bot.axnet_interface.transmit_to_axnet(command.args)
      end

      def send_help(channel, nick)
        channel.message("#{nick.name}: try ?axnet reload, maybe?")
      end

      def ping_axnet()
        @bot.axnet_interface.transmit_to_axnet('PING')
      end

      def receive_pong(handler, text)
        LOGGER.debug("PONG from #{handler.remote_cn}")
      end
      
      def handle_axnet_command(channel, nick, command)
        begin
          user = @bot.user_list.get_from_nick_object(nick)
          if (user.nil? || !user.director?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end

          if (command.args.strip.empty?)
            send_help(channel, nick)
            return
          end

          case (command.args.strip)
            when /^list$/i, /^list\s+/i
              list_axnet_connections(channel, nick)
            when /^reload$/i, /^stop\s+/i
              reload_axnet(channel, nick)
            when /^ping$/i
              ping_axnet
            else
              send_help(channel, nick)
          end
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def list_axnet_connections(channel, nick)
        bots = []
        @handlers.each do |handler|
          bots.push(handler.remote_cn)
        end
        if (bots.empty?)
          channel.message("#{nick.name}: no axnet nodes connected.")
        else
          channel.message("#{nick.name}: connected axnet nodes: #{bots.join(', ')}")
        end
      end

      def reload_axnet(channel, nick)
        channel.message("#{nick.name} issuing orders to axnet nodes to update and reload the axial codebase.")
        @bot.reload_axnet
        @bot.axnet_interface.transmit_to_axnet('RELOAD_AXNET')
        @bot.git_pull
        @bot.reload_addons
      end

      def op_and_repeat(handler, command)
        if (command.args.strip =~ /(\S+)\s+(\S+)/)
          channel_name, peer_nick_name = Regexp.last_match.captures
          @server_interface.channel_list.all_channels.each do |channel|
            LOGGER.debug("opping #{peer_nick_name} in #{channel.name}")
          end
          repeat_except(handler, "#{command.args}")
        end
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

      def close_connections()
        @handlers.each do |conn|
          conn.close
        end
        @handlers = []
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def repeat_except(exclude_handler, text)
        LOGGER.debug("repeating to #{@handlers.count - 1} connections")
        @handlers.each do |handler|
          if (handler.object_id == exclude_handler.object_id)
            next
          else
            handler.send(text)
          end
        end
      end

      def broadcast(payload)
        LOGGER.debug("broadcasting to #{@handlers.count} connections")
        @handlers.each do |handler|
          handler.send(payload)
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
        if (!@tcp_listener.nil?)
          @tcp_listener.shutdown
        end
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
                @handlers.delete(handler)
              rescue Exception => ex
                @handlers.delete(handler)
                LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                ex.backtrace.each do |i|
                  LOGGER.error(i)
                end
              end
            end
            @handlers.push(handler)
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
