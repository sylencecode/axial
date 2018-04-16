require 'yaml'
require 'axial/addon'
require 'axial/cert_utils'
require 'axial/role'
require 'axial/axnet/socket_handler'
require 'axial/axnet/user'
require 'axial/axnet/system_info'
require 'axial/colors'
require 'axial/timespan'

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


        if (axnet.slave?)
          raise(AddonError, 'attempted to load both the axnet master and slave addons')
        else
          axnet.master = true
        end

        on_startup                        :start_master_threads
        on_reload                         :start_master_threads

        on_axnet              'BANLIST',  :send_ban_list
        on_axnet             'BOT_AUTH',  :add_bot
        on_axnet             'USERLIST',  :send_user_list
        on_axnet          'SYSTEM_INFO',  :update_bot_system_info
        on_axnet            'HEARTBEAT',  :log_heartbeat

        on_axnet_disconnect               :remove_bot
        on_axnet_connect                  :announce_bot

        on_privmsg             'loreum',  :dcc_wrapper, :lorem_ipsum
        on_privmsg               'join',  :dcc_wrapper, :join_channel
        on_privmsg         'part|leave',  :dcc_wrapper, :part_channel

        on_dcc                  'lorem',  :dcc_wrapper, :lorem_ipsum
        on_dcc                   'join',  :dcc_wrapper, :join_channel
        on_dcc             'part|leave',  :dcc_wrapper, :part_channel
        on_dcc              'broadcast',  :handle_broadcast
        on_dcc                  'axnet',  :handle_axnet_command
        on_dcc                   'bots',  :dcc_bot_status

        on_channel               'ping',  :pong_channel

        axnet.register_transmitter(self, :broadcast)
        axnet.register_relay(self, :relay)
      end

      def log_heartbeat(handler, command)
        handler.send("HEARTBEAT_RESPONSE #{command.first_argument}")
      end

      def announce_bot(handler)
        dcc_broadcast("#{Colors.gray}-#{Colors.darkgreen}-#{Colors.green}> #{handler.remote_cn}#{Colors.reset} connected to axnet.", :director)
      end

      def update_bot_system_info(handler, command)
        system_info_yaml    = command.args.tr("\0", "\n")
        safe_classes        = [
          Axnet::SystemInfo,
          Git::Author,
          Git::Base,
          Git::Index,
          Git::Lib,
          Git::Repository,
          Git::WorkingDirectory,
          Git::Object::Commit,
          Git::Object::Tree,
          Symbol,
          Time
        ]
        system_info         = YAML.safe_load(system_info_yaml, safe_classes, [], true)
        handler.system_info = system_info
      end

      def join_channel(source, user, nick, command)
        if (!user.role.director?)
          dcc_access_denied(source)
        else
          channel_name, password = command.two_arguments
          if (channel_name.empty?)
            reply(source, nick, "usage: #{command.command} <nick>")
          else
            LOGGER.info("received orders to join #{channel_name} from #{user.pretty_name}")
            dcc_broadcast("#{Colors.gray}-#{Colors.darkred}-#{Colors.red}> #{user.pretty_name_with_color} issued orders to join #{channel_name}.", :director)
            if (!server.trying_to_join.key?(channel_name.downcase))
              server.trying_to_join[channel_name.downcase] = password
            end
            server.join_channel(channel_name.downcase, password)
            @bot.add_channel(channel_name.downcase, password)
            axnet.send("JOIN #{channel_name} #{password}")
          end
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def part_channel(source, user, nick, command)
        if (!user.role.director?)
          dcc_access_denied(source)
        else
          channel_name = command.first_argument
          if (channel_name.empty?)
            reply(source, nick, "usage: #{command.command} <nick>")
          else
            LOGGER.info("received orders to part #{channel_name} from #{user.pretty_name}")
            dcc_broadcast("#{Colors.gray}-#{Colors.darkred}-#{Colors.red}> #{user.pretty_name_with_color} issued orders to part #{channel_name}.", :director)
            server.trying_to_join.delete(channel_name.downcase)
            @bot.delete_channel(channel_name.downcase)
            axnet.send("PART #{channel_name}")
            if (channel_list.include?(channel_name))
              server.part_channel(channel_name.downcase)
            end
          end
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def lorem_ipsum(source, user, nick, command)
        if (!user.role.root?)
          dcc_access_denied(source)
        else
          channel_name, repeats = command.two_arguments
          if (repeats.empty?)
            reply(source, nick, "usage: #{command.command} <channel> <times>")
          else
            repeats = repeats.to_i
            channel = channel_list.get_silent(channel_name)
            if (!channel.nil?)
              LOGGER.info("received orders to flood #{channel_name} from #{user.pretty_name}")
              dcc_broadcast("#{Colors.gray}-#{Colors.darkred}-#{Colors.red}> #{user.pretty_name_with_color} issued orders to flood #{channel_name}.", :director)
              axnet.send("LOREM #{channel_name} #{repeats}")
              repeats.times do
                channel.message('Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.')
              end
            end
          end
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def pong_channel(channel, nick, command)
        user = user_list.get_from_nick_object(nick)
        if (!user.nil? && user.role.director?)
          channel.message('pong! (axnet master)')
        end
        axnet.send("PING #{channel.name}")
      end

      def print_bot_status(dcc, bot_name, max_bot_name_length, system_info)
        if (!dcc.user.role.director?)
          dcc_access_denied(source)
        else
          header        = ".---- --- --- -#{Colors.gray}--#{Colors.darkblue}--#{Colors.blue}["
          header       += " #{Colors.cyan} #{bot_name.center(max_bot_name_length)} "
          header       += "#{Colors.blue}]#{Colors.darkblue}--#{Colors.gray}--#{Colors.reset}"
          dcc.message(header)

          if (system_info.nil?)
            dcc.message('system information not yet available.')
          else
            addons = system_info.addons.clone
            addon_chunks = []
            while (addons.count >= 4)
              chunk = []
              4.times do
                chunk.push(addons.shift)
              end
              addon_chunks.push(chunk)
            end

            if (addons.any?)
              addon_chunks.push(addons)
            end

            running_since = system_info.startup_time.getlocal.strftime('%Y-%m-%d %l:%M:%S%p (%Z)')
            dcc.message("#{Colors.gray}|#{Colors.reset}            uhost: #{system_info.uhost}")
            dcc.message("#{Colors.gray}|#{Colors.reset}     connected to: #{system_info.server_info}")
            dcc.message("#{Colors.gray}|#{Colors.reset} operating system: #{system_info.os}")
            dcc.message("#{Colors.gray}|#{Colors.reset}           kernel: #{system_info.kernel_name} #{system_info.kernel_release} (#{system_info.kernel_machine})")
            dcc.message("#{Colors.gray}|#{Colors.reset}       processors: #{system_info.cpu_logical_processors} x #{system_info.cpu_model} (#{system_info.cpu_mhz}mhz)")
            dcc.message("#{Colors.gray}|#{Colors.reset}           memory: #{system_info.mem_total}mb (#{system_info.mem_free}mb free)")
            dcc.message("#{Colors.gray}|#{Colors.reset}      interpreter: ruby version #{system_info.ruby_version}p#{system_info.ruby_patch_level} (#{system_info.ruby_platform})")
            if (system_info.addons.empty?)
              dcc.message("#{Colors.gray}|#{Colors.reset}    loaded addons: none")
            else
              addon_chunks.each_with_index do |chunk, i|
                if (i.zero?)
                  dcc.message("#{Colors.gray}|#{Colors.reset}    loaded addons: #{chunk.join("#{Colors.gray} | #{Colors.reset}")}")
                else
                  dcc.message("#{Colors.gray}|#{Colors.reset}                   #{chunk.join("#{Colors.gray} | #{Colors.reset}")}")
                end
              end
            end
            if (!system_info.latest_commit.nil?)
              gc = system_info.latest_commit
              commit_string = "#{gc.date.getlocal.strftime('%Y-%m-%d %l:%M:%S%p (%Z)')} [#{gc.sha[0..7]}] - #{gc.author.name} <#{gc.author.email}>: #{gc.message}"
              dcc.message("#{Colors.gray}|#{Colors.reset}    latest commit: #{commit_string}")
            end
            dcc.message("#{Colors.gray}|#{Colors.reset}    running since: #{running_since} [#{TimeSpan.new(Time.now, system_info.startup_time).short_to_s}]")
          end
        end
      rescue Exception => ex
        dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def print_brief_status(dcc, bot_name, max_bot_name_length, system_info, max_server_info_length)
        msg  = "#{bot_name.ljust(max_bot_name_length)} #{Colors.gray}|#{Colors.reset} "
        msg += "#{system_info.server_info.ljust(max_server_info_length)} #{Colors.gray}|#{Colors.reset} "
        msg += "#{system_info.uhost}"

        dcc.message(msg)
      end

      def dcc_bot_status(dcc, command)
        brief = false
        if (command.first_argument.casecmp('brief').zero?)
          brief = true
        end

        system_info                     = Axnet::SystemInfo.from_environment
        system_info.server_info         = "#{@bot.server.real_address}:#{@bot.server.port}"
        system_info.uhost               = server.myself.uhost
        system_info.startup_time        = @bot.startup_time
        system_info.addons              = @bot.addons.collect { |addon| addon[:name] }
        system_info.latest_commit       = @bot.git&.log&.first

        if (!@bot.server.connected?)
          system_info.server_info += " (disconnected)"
        end

        if (@handlers.any?)
          max_bot_name_length       = @handlers.values.collect { |handler| handler.remote_cn.length }.max
          if (@bot.local_cn.length > max_bot_name_length)
            max_bot_name_length     = @bot.local_cn.length
          end
          max_server_info_length    = @handlers.values.collect { |handler| handler.system_info&.server_info&.length }.max
          if (system_info.server_info.length > max_server_info_length)
            max_server_info_length  = system_info.server_info.length
          end
        else
          max_bot_name_length       = @bot.local_cn.length
          max_server_info_length    = system_info.server_info.length
        end

        if (brief)
          print_brief_status(dcc, @bot.local_cn, max_bot_name_length, system_info, max_server_info_length)
        else
          print_bot_status(dcc, @bot.local_cn, max_bot_name_length, system_info)
        end

        @handlers.values.each do |handler|
          bot_name          = handler.remote_cn
          system_info       = handler.system_info

          connected_since   = handler.established_time.getlocal.strftime('%Y-%m-%d %l:%M:%S%p (%Z)')
          if (brief)
            print_brief_status(dcc, bot_name, max_bot_name_length, system_info, max_server_info_length)
          else
            print_bot_status(dcc, bot_name, max_bot_name_length, system_info)
            dcc.message("#{Colors.gray}|#{Colors.reset}  connected since: #{connected_since} [#{TimeSpan.new(Time.now, handler.established_time).short_to_s}] (from #{handler.remote_address})")
            dcc.message("#{Colors.gray}|#{Colors.reset}        axnet lag: #{system_info.lag} seconds")
          end
        end
        dcc.message('')
        case @handlers.count
          when 0
            bots_string = 'no bots'
          when 1
            bots_string = '1 bot'
          else
            bots_string = "#{@handlers.count} bots"
        end

        dcc.message("#{bots_string} connected.")
      rescue Exception => ex
        dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def remove_bot(handler)
        dcc_broadcast("#{Colors.gray}-#{Colors.darkred}-#{Colors.red}> #{handler.remote_cn}#{Colors.reset} disconnected from axnet.", :director)
        if (bot_list.include?(handler.remote_cn))
          LOGGER.debug("removing #{handler.remote_cn} from bot list")
          bot_list.delete(handler.remote_cn)
        end
      end

      def add_bot(handler, command)
        bot_yaml      = command.args.tr("\0", "\n")
        safe_classes  = [
            Axnet::User,
            Axial::Role,
            Symbol,
            Time
        ]
        new_bot       = YAML.safe_load(bot_yaml, safe_classes, [], true)

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

        serialized_yaml         = YAML.dump(bot_list).tr("\n", "\0")
        axnet.send("BOTS #{serialized_yaml}")
      end

      def handle_broadcast(dcc, command)
        if (!dcc.user.role.root?)
          dcc_access_denied(source)
          return
        end
        axnet.send(command.args)
      end

      def send_axnet_help(dcc, command)
        dcc.message("try #{command.command} reload or #{command.command} list")
      end

      def receive_pong(handler, text)
        LOGGER.debug("PONG from #{handler.uuid} (#{handler.remote_cn})")
      end

      def axnet_die(dcc)
        LOGGER.warn("received AXNET DIE command from #{dcc.user.pretty_name} - exiting in 5 seconds...")
        dcc_broadcast("#{Colors.gray}*#{Colors.darkred}*#{Colors.red}* #{dcc.user.pretty_name_with_color} issued an axnet death sentence! #{Colors.red}*#{Colors.darkred}*#{Colors.gray}*", :director)
        axnet.send('DIE')
        sleep 5
        server.send_raw("QUIT :Killed by #{dcc.user.pretty_name}.")
        sleep 5
        exit! 0
      end

      def handle_axnet_command(dcc, command)
        if (!dcc.user.role.root?)
          dcc_access_denied(source)
          return
        end

        if (command.args.strip.empty?)
          send_help(dcc, command)
          return
        end

        case (command.args.strip)
          when /^die$/i
            axnet_die(dcc)
          when /^list$/i
            list_axnet_connections(dcc)
          when /^reload$/i
            reload_axnet(dcc)
          else
            send_axnet_help(dcc, command)
        end
      rescue Exception => ex
        dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
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
          bots = @handlers.values.collect(&:remote_cn)
        end
        if (bots.empty?)
          dcc.message('no axnet nodes connected.')
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
        user_list_yaml = YAML.dump(user_list).tr("\n", "\0")
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
        ban_list_yaml = YAML.dump(ban_list).tr("\n", "\0")
        handler.send('BANLIST_RESPONSE ' + ban_list_yaml)
        LOGGER.debug("sent ban list to #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def close_connections()
        @handlers.values.each(&:close)

        @handlers = {}
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def broadcast(payload)
        if (@handlers.any?)
          handlers_string = (@handlers.count == 1) ? '1 connection' : "#{@handlers.count} connections"
          LOGGER.debug("broadcasting to #{handlers_string}")
          @handlers.values.each do |handler|
            if (handler.socket.closed? || handler.socket.eof?)
              LOGGER.debug("not sending data, connection is dead")
              next
            end
            handler.send(payload)
          end
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
            if (handler.socket.closed? || handler.socket.eof?)
              LOGGER.debug("not sending data, connection is dead")
              next
            end
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
            @ssl_listener = OpenSSL::SSL::SSLServer.new(@tcp_listener, Axial::CertUtils.get_context)
            client_socket = @ssl_listener.accept
            handler = Axnet::SocketHandler.new(@bot, client_socket)
            handler.ssl_handshake
            dupe_uuids = []
            @handlers.values.each do |tmp_handler|
              if (tmp_handler.remote_cn == handler.remote_cn)
                LOGGER.warn("duplicate connection from #{handler.remote_cn}")
                dupe_uuids.push(tmp_handler.uuid)
              end
            end
            dupe_uuids.each do |uuid|
              LOGGER.debug("closing duplicate connection handler #{uuid}")
              @handlers[uuid].close
            end
            Thread.new(handler) do |t_handler|
              begin
                @handler_monitor.synchronize do
                  bind_handler.dispatch_axnet_connect_binds(t_handler)
                end
                t_handler.loop
                @handler_monitor.synchronize do
                  bind_handler.dispatch_axnet_disconnect_binds(t_handler)
                  LOGGER.debug("deleting handler #{t_handler.uuid} (#{t_handler.remote_cn})")
                  @handlers.delete(t_handler.uuid)
                  LOGGER.debug("(#{t_handler.remote_cn} disconnected (#{t_handler.uuid})")
                end
              rescue Exception => ex
                LOGGER.warn("error close for #{t_handler.remote_cn} (#{t_handler.uuid}")
                ex.backtrace.each do |i|
                  LOGGER.error(i)
                end
                @handler_monitor.synchronize do
                  bind_handler.dispatch_axnet_disconnect_binds(t_handler)
                  @handlers.delete(t_handler.uuid)
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
        LOGGER.debug('starting axial master thread')
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

        timer.get_from_callback_method(:send_bot_list).each do |tmp_timer|
          LOGGER.debug("warning - removing errant send_bot_list timer #{tmp_timer.callback_method}")
          timer.delete(tmp_timer)
        end
        @refresh_timer  = timer.every_5_minutes(self, :send_bot_list)

        timer.get_from_callback_method(:check_for_uhost_change).each do |tmp_timer|
          LOGGER.debug("warning - removing errant check_for_uhost_change timer #{tmp_timer.callback_method}")
          timer.delete(tmp_timer)
        end
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
