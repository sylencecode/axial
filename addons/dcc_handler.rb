require 'bcrypt'
require 'socket'
require 'resolv'
require 'timeout'
require 'securerandom'
require 'axial/addon'
require 'axial/colors'
require 'axial/irc_types/dcc'
require 'axial/irc_types/dcc_state'

module Axial
  module Addons
    class DCCHandler < Axial::Addon
      def initialize(bot)
        super

        @name                     = 'dcc handler'
        @author                   = 'sylence <sylence@sylence.org>'
        @version                  = '1.1.0'

        @port                     = 54321

        @dcc_state                = IRCTypes::DCCState
        @connections              = @dcc_state.connections
        @monitor                  = @dcc_state.monitor

        @silent_commands = %w(quit help)

        on_dcc          'help',   :dcc_help
        on_dcc        'reload',   :reload_addons
        on_dcc           'who',   :dcc_who
        on_dcc          'quit',   :dcc_quit

        on_privmsg      'chat',   :start_dcc_loop
      end

      def dcc_help(dcc, command)
        dcc.message("#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        if (@bot.addons.count > 0)
          @bot.addons.each do |addon|
            channel_listeners = addon[:object].listeners.select{ |listener| listener[:type] == :dcc && listener[:command].is_a?(String) }
            listener_string = ""
            if (channel_listeners.count > 0)
              commands = channel_listeners.collect{ |bind| @bot.dcc_command_character + bind[:command] }
              dcc.message("+ #{addon[:name]}: #{commands.sort.join(', ')}")
            end
          end
        else
          dcc.message("no addons loaded.")
        end
      end

      def dcc_quit(dcc, command)
        dcc.message("goodbye.")
        dcc.stats = :closed
        socket.close
      end

      def dcc_who(dcc, command)
        dcc.message("online users:")
        @connections.each do |uuid, state_data|
          remote_dcc = state_data[:dcc]
          if (dcc.user.role.director?)
            dcc.message("  #{remote_dcc.user.pretty_name} #{Colors.gray}|#{Colors.reset} #{remote_dcc.user.role.name} #{Colors.gray}|#{Colors.reset} #{remote_dcc.remote_ip}")
          else
            dcc.message("  #{remote_dcc.user.pretty_name} #{Colors.gray}|#{Colors.reset} #{remote_dcc.user.role.name}")
          end
        end
      end

      def reload_addons(dcc, command)
        if (!dcc.user.role.director?)
          dcc.message(Constants::ACCESS_DENIED)
          return
        end

        if (@bot.addons.count == 0)
          dcc.message("no addons loaded.")
        else
          LOGGER.info("#{dcc.user.pretty_name} reloaded addons.")
          addon_list = @bot.addons.select{ |addon| addon[:name] != 'base' }
          addon_names = addon_list.collect{ |addon| addon[:name] }
          dcc.message("unloading addons: #{addon_names.join(', ')}")
          @bot.git_pull
          @bot.reload_addons
          addon_list = @bot.addons.select{ |addon| addon[:name] != 'base' }
          addon_names = addon_list.collect{ |addon| addon[:name] }
          dcc.message("loaded addons: #{addon_names.join(', ')}")
        end
      rescue Exception => ex
        dcc.message("addon reload error: #{ex.class}: #{ex.message}")
        LOGGER.error("addon reload error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def start_dcc_loop(nick, command)
        local_ip    = Resolv.getaddress(Socket.gethostname)

        user = user_list.get_from_nick_object(nick)
        if (user.nil? || !user.role.director?)
          return
        end

        LOGGER.debug("dcc chat offer to #{nick.name} (user: #{user.pretty_name})")
        fragments = local_ip.split('.')
        long_ip = 0
        block = 4
        fragments.each do |fragment|
          block -= 1
          long_ip += fragment.to_i * (256 ** block)
        end

        tcp_server = TCPServer.new(@port)
        socket = nil
        begin
          nick.message("\x01DCC CHAT chat #{long_ip} #{@port}\x01")
          Timeout.timeout(10) do
            socket = tcp_server.accept
          end
        rescue Timeout::Error
          LOGGER.error("connection attempt timed out attempting to dcc chat #{nick.name} (#{dcc.user.pretty_name})")
        end
        
        tcp_server.close
        if (!socket.nil?)
          begin
            uuid = SecureRandom.uuid
            remote_ip = socket.to_io.peeraddr[2]
            state_data = { remote_ip: remote_ip, status: :authenticating }
            dcc = IRCTypes::DCC.from_socket(state_data, @bot.server_interface, socket, user)
            state_data[:dcc] = dcc

            @monitor.synchronize do
              @connections[uuid] = state_data
            end

            attempts = 0
            dcc.message("hello #{dcc.user.pretty_name}, please enter your password.")
            auth_timeout_timer = timer.in_15_seconds do
              dcc.message("timeout.")
              dcc.close
            end

            while (text = socket.gets)
              text.strip!
              if (dcc.status == :authenticating)
                attempts += 1
                crypted = BCrypt::Password.new(user.password)
                if (crypted == text)
                  dcc.message("welcome.")
                  dcc.status = :open
                  timer.delete(auth_timeout_timer)
                  @dcc_state.broadcast("#{Colors.gray}-#{Colors.darkgreen}-#{Colors.green}>#{Colors.cyan} #{dcc.user.pretty_name}#{Colors.reset} has logged in.")
                  LOGGER.info("dcc connection established with #{dcc.user.pretty_name} (#{remote_ip}).")
                else
                  if (attempts == 3)
                    dcc.message("incorrect password after 3 attempts.")
                    dcc.status = :failed
                    dcc.close
                  else
                    dcc.message("incorrect password, attempt #{attempts} of 3.")
                  end
                end
              else
                dispatched_commands = bind_handler.dispatch_dcc_binds(dcc, text)
                if (dispatched_commands)
                  if (text != "#{@bot.dcc_command_character}quit")
                    @dcc_state.broadcast("#{Colors.gray}-#{Colors.darkblue}-#{Colors.blue}>#{Colors.cyan} #{dcc.user.pretty_name}#{Colors.reset} executed command: #{text}", :director)
                    LOGGER.info("dcc command: #{dcc.user.pretty_name}: #{text}")
                  end
                else
                  if (text.start_with?(@bot.dcc_command_character))
                    dcc.message("command not found. try #{@bot.dcc_command_character}help.")
                  else
                    @dcc_state.broadcast("#{Colors.gray}<#{Colors.cyan}#{dcc.user.pretty_name}#{Colors.gray}>#{Colors.reset} #{text}")
                  end
                end
              end
            end
            LOGGER.info("closed dcc connection with #{user.pretty_name} (#{remote_ip}): #{ex.class}: #{ex.message}")
            @monitor.synchronize do
              @connections.delete(uuid)
            end
          rescue Exception => ex
            if (!dcc.nil?)
              case dcc.status
               when :closed
                 @dcc_state.broadcast("#{Colors.red}<#{Colors.darkred}-#{Colors.gray}-#{Colors.cyan} #{dcc.user.pretty_name}#{Colors.reset} has logged out.")
                 LOGGER.info("closed dcc connection with #{user.pretty_name} (#{remote_ip})")
               when :authenticating
                 LOGGER.warn("login attempt timed out for #{user.pretty_name} (#{remote_ip})")
               when :failed
                 LOGGER.warn("failed dcc login for #{user.pretty_name} (#{remote_ip})")
               else
                 @dcc_state.broadcast("#{Colors.red}<#{Colors.darkred}-#{Colors.gray}-#{Colors.cyan} #{dcc.user.pretty_name}#{Colors.reset} has logged out.")
                 LOGGER.warn("error closing dcc connection with #{user.pretty_name} (#{remote_ip}): #{ex.class}: #{ex.message}")
             end
            else
              LOGGER.error("unexpected error establishing dcc connection with #{user.pretty_name} (#{remote_ip}): #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
            @monitor.synchronize do
              @connections.delete(uuid)
            end
          end
        else
          LOGGER.info("unknown error establishing dcc connection with #{user.pretty_name} (#{remote_ip}): #{ex.class}: #{ex.message}")
        end
      rescue Exception => ex
        LOGGER.error("error establishing dcc connection with #{user.pretty_name} (#{remote_ip}): #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
