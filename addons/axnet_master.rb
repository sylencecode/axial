require 'yaml'
require 'axial/addon'
require 'axial/cert_utils'
require 'axial/role'
require 'axial/axnet/socket_handler'
require 'axial/axnet/user'

module Axial
  module Addons
    class AxnetMaster < Axial::Addon
      def initialize(bot)
        super

        @name                             = 'axnet master'
        @author                           = 'sylence <sylence@sylence.org>'
        @version                          = '1.1.0'

        @last_uhost                       = myself.uhost
        @uhost_timer                      = nil
        @refresh_timer                    = nil
        @master_thread                    = nil
        @handlers                         = {}
        @tcp_listener                     = nil
        @ssl_listener                     = nil
        @running                          = false
        @refresh_timer                    = nil
        @handler_monitor                  = Monitor.new
        @port                             = 34567
        @bot.local_cn                     = Axial::CertUtils.get_cert_cn
        @bot_user                         = Axnet::User.new
 
        axnet.master = true

        on_startup                        :start_master_threads
        on_reload                         :start_master_threads

        on_axnet              'BANLIST',  :send_ban_list
        on_axnet             'BOT_AUTH',  :add_bot
        on_axnet             'USERLIST',  :send_user_list

        on_axnet_disconnect               :remove_bot

        on_privmsg               'join',  :dcc_wrapper, :join_channel
        on_privmsg         'part|leave',  :dcc_wrapper, :part_channel

        on_dcc              'broadcast',  :handle_broadcast
        on_dcc                  'axnet',  :handle_axnet_command
        on_dcc             'connstatus',  :display_conn_status

        on_privmsg               'join',  :dcc_wrapper, :join_channel
        on_privmsg         'part|leave',  :dcc_wrapper, :part_channel

        on_channel               'ping',  :pong_channel

        axnet.register_transmitter(self, :broadcast)
        axnet.register_relay(self, :relay)
      end

      def join_channel(source, user, nick, command)
        if (!user.role.director?)
          dcc_access_denied(source)
        else
          channel_name, password = command.two_arguments
          dcc_broadcast("#{Colors.gray}-#{Colors.darkred}-#{Colors.red}> #{user.pretty_name_with_color} issued orders to join #{channel_name}.", :director)
          if (!server.trying_to_join.has_key?(channel_name.downcase))
            server.trying_to_join[channel_name.downcase] = password
          end
          server.join_channel(channel_name.downcase, password)
          @bot.add_channel(channel_name.downcase, password)
          axnet.send("JOIN #{channel_name} #{password}")
        end
      end

      def part_channel(source, user, nick, command)
        if (!user.role.director?)
          dcc_access_denied(source)
        else
          channel_name = command.first_argument
          dcc_broadcast("#{Colors.gray}-#{Colors.darkred}-#{Colors.red}> #{user.pretty_name_with_color} issued orders to part #{channel_name}.", :director)
          if (server.trying_to_join.has_key?(channel_name.downcase))
            server.trying_to_join.delete(channel_name.downcase)
          end
          server.part_channel(channel_name.downcase)
          @bot.delete_channel(channel_name.downcase, password)
          axnet.send("PART #{channel_name}")
        end
      end

      def pong_channel(channel, nick, command)
        user = user_list.get_from_nick_object(nick)
        if (!user.nil? && user.role.director?)
          channel.message("pong! (axnet master)")
        end
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

      def remove_bot(handler)
        if (bot_list.include?(handler.remote_cn))
          LOGGER.debug("removing #{handler.remote_cn} from bot list")
          bot_list.delete(handler.remote_cn)
        end
      end

      def add_bot(handler, command)
        bot_yaml = command.args.gsub(/\0/, "\n")
        new_bot = YAML.load(bot_yaml)
        if (bot_list.include?(new_bot.name))
          bot_list.delete(new_bot.name)
        end
        bot_list.add(new_bot)
        LOGGER.info("updating bot_user info for #{new_bot.pretty_name}")
        send_bot_list
      end

      def send_bot_list()
        @bot_user.name          = @bot.local_cn
        @bot_user.pretty_name   = @bot.local_cn
        @bot_user.role_name     = 'bot'
        @bot_user.role          = Role.new('bot')
        @bot_user.id            = 0

        if (!myself.uhost.empty?)
          @bot_user.masks       = [ MaskUtils.ensure_wildcard(myself.uhost) ]
        end

        if (bot_list.include?(@bot_user.name))
          bot_list.delete(@bot_user.name)
        end
        bot_list.add(@bot_user)

        serialized_yaml         = YAML.dump(bot_list).gsub(/\n/, "\0")
        axnet.send("BOTS #{serialized_yaml}")
      end

      def handle_broadcast(dcc, command)
        axnet.send(command.args)
      end

      def send_help(dcc, command)
        dcc.message("try #{command.command} reload or #{command.command} list")
      end

      def receive_pong(handler, text)
        LOGGER.debug("PONG from #{handler.uuid} (#{handler.remote_cn})")
      end
      
      def handle_axnet_command(dcc, command)
        begin
          if (command.args.strip.empty?)
            send_help(dcc, command)
            return
          end

          case (command.args.strip)
            when /^list$/i, /^list\s+/i
              list_axnet_connections(dcc)
            when /^reload$/i, /^stop\s+/i
              reload_axnet(dcc)
            else
              send_help(dcc, command)
          end
        rescue Exception => ex
          dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def check_for_uhost_change()
        if (!myself.uhost.casecmp(@last_uhost).zero?)
          LOGGER.debug("uhost changed from #{@last_uhost} to #{myself.uhost}")
          @last_uhost = myself.uhost
          send_bot_list
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
        dcc_broadcast("#{Colors.gray}-#{Colors.darkblue}-#{Colors.blue}> #{dcc.user.pretty_name_with_color} issued an axnet reload request.", :director)
        axnet.send('RELOAD_AXNET')
        @bot.git_pull
        @bot.reload_axnet
        @bot.reload_addons
      end

      def send_user_list(handler, command)
        LOGGER.debug("user list requested from #{handler.remote_cn}")
        user_list_yaml = YAML.dump(user_list).gsub(/\n/, "\0")
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
        ban_list_yaml = YAML.dump(ban_list).gsub(/\n/, "\0")
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
        timer.delete(@refresh_timer)
        timer.delete(@uhost_timer)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
      end

      def listen()
        begin
          @tcp_listener = TCPServer.new(@port)
        rescue Errno::EADDRINUSE => ex
          LOGGER.error("axnet master can't bind to port #{@port}, it is already in use.")
          @running = false
        end
        LOGGER.info("axnet master listening for connections on port #{@port}")

        while (@running)
          begin
            @ssl_listener = OpenSSL::SSL::SSLServer::new(@tcp_listener, Axial::CertUtils.get_context)
            client_socket = @ssl_listener.accept
            handler = Axnet::SocketHandler.new(@bot, client_socket)
            handler.ssl_handshake
            dupe_uuids = []
            @handlers.each do |uuid, tmp_handler|
              if (tmp_handler.remote_cn == handler.remote_cn)
                LOGGER.warn("duplicate connection from #{handler.remote_cn}")
                dupe_uuids.push(tmp_handler.uuid)
              end
            end
            dupe_uuids.each do |uuid|
              LOGGER.debug("closing duplicate connection handler #{uuid}")
              @handlers[uuid].close
            end
            Thread.new(handler) do |handler|
              begin
                @handler_monitor.synchronize do
                  bind_handler.dispatch_axnet_connect_binds(handler)
                end
                handler.loop
                @handler_monitor.synchronize do
                  bind_handler.dispatch_axnet_disconnect_binds(handler)
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
                  bind_handler.dispatch_axnet_disconnect_binds(handler)
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
        @refresh_timer = timer.every_minute(self, :send_bot_list)
        @uhost_timer   = timer.every_second(self, :check_for_uhost_change)
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: shutting down axnet master listener")
        stop_master_threads
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
