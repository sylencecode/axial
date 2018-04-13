require 'bcrypt'
require 'socket'
require 'resolv'
require 'timeout'
require 'securerandom'
require 'axial/addon'
require 'axial/colors'
require 'axial/irc_types/dcc'

module Axial
  module Addons
    class DCCHandler < Axial::Addon
      def initialize(bot)
        super

        @name                     = 'dcc handler'
        @author                   = 'sylence <sylence@sylence.org>'
        @version                  = '1.1.0'

        @dcc_timeout              = 30
        @dcc_ports                = Array(54321..54329)

        @ports_in_use             = []

        @dcc_state                = @bot.dcc_state
        @connections              = @dcc_state.connections
        @monitor                  = @dcc_state.monitor
        @port_monitor             = @dcc_state.port_monitor

        throttle                  10

        on_dcc          'help',   :silent, :dcc_help
        on_dcc        'reload',   :reload_addons
        on_dcc           'who',   :dcc_who
        on_dcc          'quit',   :silent, :dcc_quit

        on_privmsg      'chat',   :start_dcc_loop
        on_user_list              :check_for_user_updates
      end

      def check_for_user_updates()
      end

      def dcc_help(dcc, command)
        dcc.message("#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        if (@bot.addons.any?)
          @bot.addons.each do |addon|
            dcc_binds = addon[:object].binds.select { |bind| bind[:type] == :dcc && bind[:command].is_a?(String) }
            if (dcc_binds.any?)
              commands = dcc_binds.collect { |bind| bind[:command] }.sort_by { |command| command.gsub(/^\+/, '').gsub(/^-/, '') }.collect { |command| @bot.dcc_command_character + command }
              dcc.message("+ #{addon[:name]}: #{commands.join(', ')}")
            end
          end
        else
          dcc.message('no addons loaded.')
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dcc_quit(dcc, command)
        dcc.message('goodbye.')
        dcc.status = :closed
        dcc.close
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dcc_who(dcc, command)
        dcc.message('online users:')
        @connections.each do |uuid, state_data|
          remote_dcc = state_data[:dcc]
          dcc.message("  #{remote_dcc.user.pretty_name} #{Colors.gray}|#{Colors.reset} #{remote_dcc.user.role.name_with_color} #{Colors.gray}|#{Colors.reset} #{remote_dcc.remote_ip}")
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def reload_addons(dcc, command)
        if (!dcc.user.role.director?)
          dcc.message(Constants::ACCESS_DENIED)
          return
        end

        if (@bot.addons.empty?)
          dcc.message('no addons loaded.')
        else
          LOGGER.info("#{dcc.user.pretty_name} reloaded addons.")
          dcc_broadcast("#{Colors.gray}-#{Colors.darkblue}-#{Colors.blue}> #{dcc.user.pretty_name_with_color} reloaded addons.")
          addon_list = @bot.addons.reject { |addon| addon[:name] == 'base' }
          addon_names = addon_list.collect { |addon| addon[:name] }
          dcc.message("unloading addons: #{addon_names.join(', ')}")
          @bot.git_pull
          @bot.reload_addons
          addon_list = @bot.addons.reject { |addon| addon[:name] == 'base' }
          addon_names = addon_list.collect { |addon| addon[:name] }
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
        if (user.nil? || user.role < :friend)
          return
        elsif (!user.password_set?)
          nick.message("you do not have a password set. please set one with /msg #{myself.name} PASSWORD <password>. please employ secure password practices.")
          return
        end
        fragments = local_ip.split('.')
        long_ip = 0
        block = 4
        fragments.each do |fragment|
          block -= 1
          long_ip += fragment.to_i * (256 ** block)
        end

        next_port = nil

        @port_monitor.synchronize do
          @ports_in_use.delete(next_port)
          available_ports = @dcc_ports - @ports_in_use

          if (available_ports.empty?)
            nick.message('all dcc ports are currently in use. please wait a few seconds and try again.')
          else
            next_port = available_ports.first
            @ports_in_use.push(next_port)
          end
        end

        if (next_port.nil?)
          return
        end

        Thread.new do
          tcp_server = TCPServer.new(next_port)
          socket = nil
          begin
            dcc_broadcast("#{Colors.gray}-#{Colors.darkblue}-#{Colors.blue}>#{Colors.cyan} #{Colors.reset}sent dcc chat offer to #{nick.uhost}", :director)
            LOGGER.debug("dcc chat offer to #{nick.name} (user: #{user.pretty_name}) (source: #{local_ip}:#{next_port})")
            nick.message("\x01DCC CHAT chat #{long_ip} #{next_port}\x01")
            Timeout.timeout(@dcc_timeout) do
              socket = tcp_server.accept
            end
          rescue Timeout::Error
            @port_monitor.synchronize do
              @ports_in_use.delete(next_port)
            end
            dcc_broadcast("#{Colors.gray}-#{Colors.darkblue}-#{Colors.blue}>#{Colors.cyan} #{Colors.reset}dcc chat offer to #{nick.uhost} timed out.", :director)
            LOGGER.error("connection attempt timed out attempting to dcc chat #{nick.name} (#{user.pretty_name})")
          end

          tcp_server.close
          @port_monitor.synchronize do
            @ports_in_use.delete(next_port)
          end
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
              dcc.message("hello #{dcc.user.pretty_name_with_color}, please enter your password.")
              auth_timeout_timer = timer.in_15_seconds do
                dcc.message('timeout.')
                dcc.close
              end

              while (text = socket.gets)
                text.strip!
                if (dcc.status == :authenticating)
                  attempts += 1
                  if (user.password?(text))
                    dcc.message("welcome. type '#{@bot.dcc_command_character}help' for a list of available commands.")
                    dcc.status = :open
                    timer.delete(auth_timeout_timer)
                    dcc_broadcast("#{Colors.gray}-#{Colors.darkgreen}-#{Colors.green}> #{dcc.user.pretty_name_with_color} has logged in.")
                    LOGGER.info("dcc connection established with #{dcc.user.pretty_name} (#{remote_ip}).")
                  else
                    if (attempts == 3)
                      dcc.message('incorrect password after 3 attempts.')
                      dcc_broadcast("#{Colors.gray}-#{Colors.darkblue}-#{Colors.blue}>#{Colors.cyan} #{Colors.reset}dcc: 3 failed password attempts from #{dcc.user.pretty_name_with_color}#{Colors.reset}.", :director)
                      dcc.status = :failed
                      dcc.close
                    else
                      dcc.message("incorrect password, attempt #{attempts} of 3.")
                    end
                  end
                else
                  dispatched_commands = bind_handler.dispatch_dcc_binds(dcc, text)
                  if (dispatched_commands.any?)
                    dispatched_commands.each do |dispatched_command|
                      if (!dispatched_command[:silent])
                        dcc_broadcast("#{Colors.gray}-#{Colors.darkblue}-#{Colors.blue}> #{dcc.user.pretty_name_with_color} executed command: #{text}", :director)
                        LOGGER.info("dcc command: #{dcc.user.pretty_name}: #{text}")
                      end
                    end
                  else
                    if (text.start_with?(@bot.dcc_command_character))
                      dcc.message("command not found. try #{@bot.dcc_command_character}help")
                    else
                      dcc_broadcast("#{Colors.gray}<#{dcc.user.pretty_name_with_color}#{Colors.gray}>#{Colors.reset} #{text}")
                    end
                  end
                end
              end
              LOGGER.info("closed dcc connection with #{user.pretty_name} (#{remote_ip}).")
              @monitor.synchronize do
                @connections.delete(uuid)
              end
            rescue Exception => ex
              if (!dcc.nil?)
                case dcc.status
                  when :closed
                    dcc_broadcast("#{Colors.red}<#{Colors.darkred}-#{Colors.gray}-#{Colors.cyan} #{dcc.user.pretty_name}#{Colors.reset} has logged out.")
                    LOGGER.info("closed dcc connection with #{user.pretty_name} (#{remote_ip})")
                  when :authenticating
                    LOGGER.warn("login attempt timed out for #{user.pretty_name} (#{remote_ip})")
                  when :failed
                    LOGGER.warn("failed dcc login for #{user.pretty_name} (#{remote_ip})")
                  else
                    dcc_broadcast("#{Colors.red}<#{Colors.darkred}-#{Colors.gray}-#{Colors.cyan} #{dcc.user.pretty_name}#{Colors.reset} has logged out.")
                    LOGGER.warn("error closing dcc connection with #{user.pretty_name} (#{remote_ip}): #{ex.class}: #{ex.message}")
                    ex.backtrace.each do |i|
                      LOGGER.warn(i)
                    end
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
            LOGGER.info("establishing dcc connection with #{user.pretty_name}: no response after #{@dcc_timeout} seconds")
          end
        rescue Exception => ex
          LOGGER.error("error establishing dcc connection with #{user.pretty_name} (#{remote_ip}): #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
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
