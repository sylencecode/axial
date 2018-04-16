require 'yaml'
require 'axial/addon'
require 'axial/cert_utils'
require 'axial/axnet/socket_handler'
require 'axial/axnet/user'
require 'axial/axnet/system_info'

module Axial
  module Addons
    class AxnetSlave < Axial::Addon
      def initialize(bot)
        super

        @name    = 'axnet slave'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        @last_uhost                       = myself.uhost
        @heartbeat_timer                  = nil
        @uhost_timer                      = nil
        @refresh_timer                    = nil
        @slave_thread                     = nil
        @running                          = false
        @port                             = 34567
        @handler                          = nil
        @master_address                   = 'axial.sylence.org'
        @bot.local_cn                     = Axial::CertUtils.get_cert_cn
        @bot_user                         = Axnet::User.new
        @last_heartbeat                   = Time.now

        if (axnet.master?)
          raise(AddonError, 'attempted to load both the axnet master and slave addons')
        end

        on_startup                        :start_slave_thread
        on_reload                         :start_slave_thread
        on_axnet_connect                  :axnet_login
        on_axnet_disconnect               :axnet_disconnect

        on_axnet    'USERLIST_RESPONSE',  :update_user_list
        on_axnet                 'BOTS',  :update_bot_list
        on_axnet     'BANLIST_RESPONSE',  :update_ban_list
        on_axnet         'RELOAD_AXNET',  :reload_axnet
        on_axnet                 'JOIN',  :join_channel
        on_axnet                 'PART',  :part_channel
        on_axnet                'LOREM',  :lorem_ipsum
        on_axnet                 'PING',  :pong_channel
        on_axnet                  'DIE',  :axnet_die
        on_axnet   'HEARTBEAT_RESPONSE',  :check_heartbeat

        axnet.register_transmitter(self, :send)
      end

      def check_heartbeat(handler, command)
        @last_heartbeat = Time.now
        lag = (Time.now - Time.at(command.first_argument.to_i)).to_f.round(3)
        LOGGER.debug("lag to #{handler.remote_cn}: #{lag} seconds")
      end

      def axnet_die(handler, _command)
        LOGGER.warn("received AXNET DIE command from #{handler.remote_cn} - exiting in 5 seconds...")
        sleep 5
        @server_interface.send_raw("QUIT :Killed by #{dcc.user.pretty_name}.")
        sleep 5
        exit! 0
      end

      def send_axnet_heartbeat()
        if (Time.now - @last_heartbeat > 45)
          @handler.close
        else
          axnet.send("HEARTBEAT #{Time.now.to_f}")
        end
      end

      def lorem_ipsum(handler, command)
        channel_name, repeats = command.two_arguments
        channel = channel_list.get_silent(channel_name)
        if (!channel.nil?)
          repeats = repeats.to_i
          LOGGER.info("received orders to flood #{channel_name} from #{handler.remote_cn}")
          repeats.times do
            channel.message('Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.')
          end
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def join_channel(handler, command)
        channel_name, password = command.two_arguments
        LOGGER.info("received orders to join #{channel_name} from #{handler.remote_cn}")
        if (!server.trying_to_join.key?(channel_name.downcase))
          server.trying_to_join[channel_name.downcase] = password
        end
        server.join_channel(channel_name.downcase, password)
        @bot.add_channel(channel_name.downcase, password)
      end

      def part_channel(handler, command)
        channel_name = command.first_argument
        LOGGER.info("received orders to part #{channel_name} from #{handler.remote_cn}")
        server.trying_to_join.delete(channel_name.downcase)
        server.part_channel(channel_name.downcase)
        @bot.delete_channel(channel_name.downcase)
      end

      def pong_channel(handler, command)
        channel_name = command.first_argument
        channel = channel_list.get_silent(channel_name)
        if (!channel.nil?)
          channel.message("pong! (axnet slave, pinged by #{handler.remote_cn})")
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
        LOGGER.debug("authenticating to axnet")
        @bot_user.name              = @bot.local_cn
        @bot_user.pretty_name       = @bot.local_cn
        @bot_user.role_name         = 'bot'
        @bot_user.role              = Role.new('bot')
        @bot_user.id                = 0

        if (!myself.uhost.empty?)
          @bot_user.masks           = [ MaskUtils.ensure_wildcard(myself.uhost) ]
        end

        system_info                 = Axnet::SystemInfo.from_environment
        system_info.server_info     = "#{@bot.server.real_address}:#{@bot.server.port}"
        system_info.uhost           = server.myself.uhost
        system_info.startup_time    = @bot.startup_time
        system_info.addons          = @bot.addons.collect { |addon| addon[:name] }
        system_info.latest_commit   = @bot.git&.log&.first

        if (!@bot.server.connected?)
          system_info.server_info += " (disconnected)"
        end

        auth_yaml                   = YAML.dump(@bot_user).tr("\n", "\0")
        system_info_yaml            = YAML.dump(system_info).tr("\n", "\0")

        axnet.send('BOT_AUTH '      + auth_yaml)
        axnet.send('SYSTEM_INFO '   + system_info_yaml)
      end

      def update_bot_list(handler, command)
        bot_list_yaml   = command.args.tr("\0", "\n")
        safe_classes    = [
            Axnet::UserList,
            Axnet::User,
            Axial::Role,
            Monitor,
            Symbol,
            Thread::Mutex,
            Time
        ]
        new_bot_list    = YAML.safe_load(bot_list_yaml, safe_classes, [], true)

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
        LOGGER.info('axnet reload complete.')
      end

      def update_user_list(handler, command)
        user_list_yaml  = command.args.tr("\0", "\n")
        safe_classes    = [
            Axnet::UserList,
            Axnet::User,
            Axial::Role,
            Monitor,
            Symbol,
            Thread::Mutex,
            Time
        ]
        new_user_list   = YAML.safe_load(user_list_yaml, safe_classes, [], true)

        axnet.update_user_list(new_user_list)
        LOGGER.info("successfully downloaded new userlist from #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_ban_list(handler, command)
        ban_list_yaml   = command.args.tr("\0", "\n")
        safe_classes    = [
            Axnet::BanList,
            Axnet::Ban,
            Axnet::User,
            Axial::Role,
            Monitor,
            Symbol,
            Thread::Mutex,
            Time
        ]
        new_ban_list    = YAML.safe_load(ban_list_yaml, safe_classes, [], true)

        axnet.update_ban_list(new_ban_list)
        LOGGER.info("successfully downloaded new banlist from #{handler.remote_cn}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def client()
        LOGGER.info("connecting to #{@master_address}:#{@port}")
        while (@running)
          begin
            tcp_socket = TCPSocket.new(@master_address, @port)
            ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, Axial::CertUtils.get_context)
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
        LOGGER.error('retry executes in 5 seconds...')
        sleep 5
        retry
      end

      def start_slave_thread()
        LOGGER.debug('starting axial slave thread')

        @running        = true
        timer.get_from_callback_method(:send_axnet_heartbeat).each do |tmp_timer|
          LOGGER.debug("removing previous slave send_axnet_heartbeat timer #{tmp_timer.callback_method}")
          timer.delete(tmp_timer)
        end
        @heartbeat_timer = timer.every_minute(self, :send_axnet_heartbeat)

        timer.get_from_callback_method(:auth_to_axnet).each do |tmp_timer|
          LOGGER.debug("removing previous slave auth_to_axnet timer #{tmp_timer.callback_method}")
          timer.delete(tmp_timer)
        end
        @refresh_timer  = timer.every_5_minutes(self, :auth_to_axnet)

        timer.get_from_callback_method(:check_for_uhost_change).each do |tmp_timer|
          LOGGER.debug("removing previous slave check_for_uhost_change timer #{tmp_timer.callback_method}")
          timer.delete(tmp_timer)
        end
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
        LOGGER.debug('slave thread exiting')
        @running = false
        @handler.close
        if (!@slave_thread.nil?)
          @slave_thread.kill
        end
        @slave_thread = nil
        timer.delete(@heartbeat_timer)
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
