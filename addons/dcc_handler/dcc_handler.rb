require 'bcrypt'
require 'socket'
require 'resolv'
require 'timeout'
require 'securerandom'
require 'axial/addon'
require 'axial/color'
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
        @dcc_ports                = Array(54321..54329) # rubocop:disable Style/NumericLiterals

        @ports_in_use             = []

        @dcc_state                = @bot.dcc_state
        @connections              = @dcc_state.connections
        @monitor                  = @dcc_state.monitor
        @port_monitor             = @dcc_state.port_monitor

        throttle                  10

        load_binds
      end

      def load_binds()
        on_dcc          'help',   :silent, :dcc_send_help
        on_dcc         'about',   :silent, :dcc_send_about
        on_dcc        'reload',   :reload_addons
        on_dcc           'who',   :dcc_who
        on_dcc          'quit',   :silent, :dcc_quit
        on_dcc           'die',   :dcc_die

        on_privmsg      'chat',   :dcc_chat

        on_user_list              :check_for_user_updates
      end

      # TODO: See https://www.sylence.org/code/sylence/axial/issues/69
      def check_for_user_updates(); end

      def dcc_die(dcc, _command)
        LOGGER.warn("received DIE command from #{dcc.user.pretty_name} - exiting in 5 seconds...")
        dcc_broadcast("#{Color.gray}*#{Color.darkred}*#{Color.red}* #{dcc.user.pretty_name_with_color} has issued a DIE comamnd! #{Color.red}*#{Color.darkred}*#{Color.gray}*", :director)
        sleep 5
        server.send_raw("QUIT :Killed by #{dcc.user.pretty_name}.")
        sleep 5
        exit! 0
      end

      def dcc_send_about(dcc, _command) # rubocop:disable Metrics/AbcSize
        addon_name_length = @bot.addons.collect { |tmp_addon| tmp_addon[:name].length }.max
        addon_version_length = @bot.addons.collect { |tmp_addon| tmp_addon[:version].to_s.length }.max
        dcc.message("#{Constants::AXIAL_LOGO} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (interpreter: ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        dcc.message(' ')
        if (@bot.addons.any?)
          @bot.addons.each do |addon|
            dcc.message(Color.gray(' + ') + Color.blue(addon[:name].rjust(addon_name_length)) + Color.gray(' | ') + "v#{addon[:version].to_s.rjust(addon_version_length)}" + Color.gray(' | ') + addon[:author])
          end
        else
          dcc.message('no addons loaded.')
        end
      end

      def get_command_chunks(commands, max_command_length)
        command_chunks = []

        while (commands.count >= 6)
          chunk = []
          6.times do
            tmp_command = commands.shift.ljust(max_command_length)
            chunk.push(tmp_command)
          end
          command_chunks.push(chunk)
        end

        if (commands.any?)
          command_chunks.push(commands.collect { |tmp_command| tmp_command.ljust(max_command_length) })
        end

        return command_chunks
      end

      def get_names_with_binds() # rubocop:disable Naming/AccessorMethodName, Metrics/AbcSize
        exclude_addons = [ 'axnet assistant', 'axnet master', 'axnet slave', 'base' ]
        selected_addons = @bot.addons.reject { |tmp_addon| exclude_addons.include?(tmp_addon[:name].downcase) }
        names_with_binds = selected_addons.collect { |tmp_addon| { name: tmp_addon[:name], binds: tmp_addon[:object].binds.clone } }

        names_with_binds.each do |name_with_binds|
          name_with_binds[:binds].delete_if { |tmp_bind| tmp_bind[:type] != :dcc || !tmp_bind[:command].is_a?(String) }
          name_with_binds[:binds].collect! { |tmp_bind| tmp_bind[:command] }
          name_with_binds[:binds].sort_by! { |tmp_command| tmp_command.gsub(/^\+/, '').gsub(/^-/, '') }
          name_with_binds[:binds].collect! { |tmp_command| @bot.dcc_command_character + tmp_command }
        end

        names_with_binds.delete_if { |tmp_bind| tmp_bind[:binds].empty? }
        return names_with_binds
      end

      def print_dcc_commands(dcc, names_with_binds) # rubocop:disable Metrics/AbcSize
        if (names_with_binds.empty?)
          return
        end

        addon_name_length = names_with_binds.collect { |tmp_bind| tmp_bind[:name].length }.max + 2
        max_command_length = names_with_binds.collect { |tmp_bind| tmp_bind[:binds].collect(&:length).max }.max + 2

        names_with_binds.each do |name_with_binds|
          remaining_chunks = get_command_chunks(name_with_binds[:binds], max_command_length)

          first_chunk = remaining_chunks.shift
          dcc.message(Color.blue(name_with_binds[:name].rjust(addon_name_length)) + Color.gray(' | ') + first_chunk.join(Color.gray(' | ')))
          remaining_chunks.each do |tmp_chunk|
            dcc.message(' '.ljust(addon_name_length) + Color.gray(' | ') + tmp_chunk.join(Color.gray(' | ')))
          end
        end
      end

      def dcc_send_help(dcc, _command)
        dcc.message("                    #{Constants::AXIAL_LOGO} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        dcc.message(' ')

        if (@bot.addons.empty?)
          dcc.message('no addons loaded.')
          return
        end

        names_with_binds = get_names_with_binds

        print_dcc_commands(dcc, names_with_binds)
      rescue Exception => ex
        dcc.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dcc_quit(dcc, _command)
        dcc.message('goodbye.')
        dcc.status = :closed
        dcc.close
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dcc_who(dcc, _command)
        dcc.message('online users:')
        @connections.values.each do |state_data|
          remote_dcc = state_data[:dcc]
          msg  = "  #{remote_dcc.user.pretty_name}" + Color.gray(' | ') + remote_dcc.user.role.name_with_color
          msg += Color.gray(' | ') + remote_dcc.remote_ip
          dcc.message(msg)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def reload_addons(dcc, _command) # rubocop:disable Metrics/AbcSize
        if (!dcc.user.role.director?)
          dcc.message(Constants::ACCESS_DENIED)
          return
        end

        if (@bot.addons.empty?)
          dcc.message('no addons loaded.')
        else
          LOGGER.info("#{dcc.user.pretty_name} reloaded addons.")
          dcc_broadcast(Color.blue_arrow + dcc.user.pretty_name_with_color + 'reloaded addons.')
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

      def get_long_ip(local_ip)
        long_ip = 0
        block = 4

        fragments = local_ip.split('.')
        fragments.each do |fragment|
          block -= 1
          long_ip += fragment.to_i * (256 ** block)
        end

        return long_ip
      end

      def get_available_dcc_port() # rubocop:disable Naming/AccessorMethodName
        next_port = nil

        @port_monitor.synchronize do
          @ports_in_use.delete(next_port)
          available_ports = @dcc_ports - @ports_in_use
          if (available_ports.any?)
            next_port = available_ports.first
            @ports_in_use.push(next_port)
          end
        end

        return next_port
      end

      def release_dcc_port(port)
        @port_monitor.synchronize do
          @ports_in_use.delete(port)
        end
      end

      def send_dcc_offer(nick, user, local_ip, long_ip, port)
        dcc_broadcast(Color.blue_arrow + "sent dcc chat offer to #{nick.uhost}", :director)
        LOGGER.debug("dcc chat offer to #{nick.name} (user: #{user.pretty_name}) (source: #{local_ip}:#{port})")
        nick.message("\x01DCC CHAT chat #{long_ip} #{port}\x01")
      end

      def open_dcc_socket(nick, user, local_ip, long_ip, port)
        send_dcc_offer(nick, user, local_ip, long_ip, port)
        tcp_server = TCPServer.new(port)
        socket = nil

        Timeout.timeout(@dcc_timeout) do
          socket = tcp_server.accept
        end

        tcp_server.close
        release_dcc_port(port)
        return socket
      rescue Timeout::Error
        release_dcc_port(port)
        dcc_broadcast(Color.blue_arrow + "dcc chat offer to #{nick.uhost} timed out.", :director)
        LOGGER.error("connection attempt timed out attempting to dcc chat #{nick.name} (#{user.pretty_name})")
      end

      def dcc_chat(nick, _command) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        user = user_list.get_from_nick_object(nick)
        if (user.nil? || user.role < :friend)
          return
        end

        if (!user.password_set?)
          nick.message("you do not have a password set. please set one with /msg #{myself.name} PASSWORD <password>. please employ secure password practices.")
          return
        end

        local_ip = Resolv.getaddress(Socket.gethostname)
        long_ip = get_long_ip(local_ip)
        port = get_available_dcc_port

        if (port.nil?)
          nick.message('all dcc ports are currently in use. please wait a few seconds and try again.')
        end

        Thread.new do
          begin
            socket = open_dcc_socket(nick, user, local_ip, long_ip, port)
            state_data = register_dcc_connection(socket, user)
            remote_ip = state_data[:remote_ip]

            start_dcc_handler(socket, state_data, user)
          rescue Exception => ex
            LOGGER.error("error establishing dcc connection with #{user.pretty_name} (#{remote_ip}): #{ex.class}: #{ex.message}")
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

      def delete_dcc_connection(uuid)
        @monitor.synchronize do
          @connections.delete(uuid)
        end
      end

      def register_dcc_connection(socket, user)
        uuid = SecureRandom.uuid
        remote_ip = socket.to_io.peeraddr[2]
        state_data = { remote_ip: remote_ip, status: :authenticating }
        dcc = IRCTypes::DCC.from_socket(state_data, @bot.server_interface, socket, user)
        state_data[:dcc] = dcc
        state_data[:uuid] = uuid

        @monitor.synchronize do
          @connections[uuid] = state_data
        end

        return state_data
      end

      def try_authentication(dcc, text, state_data, auth_timeout_timer, password_attempts)
        remote_ip = state_data[:remote_ip]
        if (dcc.user.password?(text))
          dcc.message("welcome. type '#{@bot.dcc_command_character}help' for a list of available commands.")
          dcc.status = :open
          timer.delete(auth_timeout_timer)
          dcc_broadcast(Color.green_arrow + dcc.user.pretty_name_with_color + ' has logged in.')
          LOGGER.info("dcc connection established with #{dcc.user.pretty_name} (#{remote_ip}).")
        elsif (password_attempts >= 3)
          dcc.message('incorrect password after 3 attempts.')
          dcc_broadcast(Color.blue_arrow + "dcc: 3 failed password attempts from #{dcc.user.pretty_name_with_color}.", :director)
          dcc.status = :failed
          dcc.close
          timer.delete(auth_timeout_timer)
        else
          dcc.message("incorrect password, attempt #{password_attempts} of 3.")
        end
      end

      def dcc_loop(socket, state_data) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        dcc = state_data[:dcc]

        password_attempts = 0
        dcc.message("hello #{dcc.user.pretty_name_with_color}, please enter your password.")
        auth_timeout_timer = timer.in_15_seconds do
          dcc.message('timeout.')
          dcc.close
        end

        while (text = socket.gets)
          text.strip!
          if (dcc.status == :authenticating)
            password_attempts += 1
            try_authentication(dcc, text, state_data, auth_timeout_timer, password_attempts)
          else
            dispatched_commands = bind_handler.dispatch_dcc_binds(dcc, text)
            if (dispatched_commands.any?)
              dispatched_commands.each do |dispatched_command|
                if (!dispatched_command[:silent]) # rubocop:disable Metrics/BlockNesting
                  dcc_broadcast(Color.blue_arrow + dcc.user.pretty_name_with_color + " executed command: #{text}", :director)
                  LOGGER.info("dcc command: #{dcc.user.pretty_name}: #{text}")
                end
              end
            elsif (text.start_with?(@bot.dcc_command_character))
              dcc.message("command not found. try #{@bot.dcc_command_character}help")
            else
              dcc_broadcast("#{Color.gray}<#{dcc.user.pretty_name_with_color}#{Color.gray}>#{Color.reset} #{text}")
            end
          end
        end
      end

      def start_dcc_handler(socket, state_data, user) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        if (socket.nil?)
          LOGGER.info("error establishing dcc connection with #{user.pretty_name}: no response after #{@dcc_timeout} seconds")
          return
        end

        dcc = state_data[:dcc]

        remote_ip = state_data[:remote_ip]
        dcc_loop(socket, state_data)

        LOGGER.info("closed dcc connection with #{user.pretty_name} (#{remote_ip}).")
        delete_dcc_connection(state_data[:uuid])
      rescue Exception => ex
        if (!dcc.nil?)
          case dcc.status
            when :closed
              dcc_broadcast(Color.red_arrow_reverse + dcc.user.pretty_name_with_color + ' has logged out.')
              LOGGER.info("closed dcc connection with #{user.pretty_name} (#{remote_ip})")
            when :authenticating
              LOGGER.warn("login attempt timed out for #{user.pretty_name} (#{remote_ip})")
            when :failed
              LOGGER.warn("failed dcc login for #{user.pretty_name} (#{remote_ip})")
            else
              dcc_broadcast(Color.red_arrow_reverse + dcc.user.pretty_name_with_color + ' has logged out.')
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
        delete_dcc_connection(state_data[:uuid])
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}", __FILE__, __LINE__)
        end
      end
    end
  end
end
