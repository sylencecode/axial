require 'socket'
require 'resolv'
require 'timeout'
require 'axial/addon'

module Axial
  module Addons
    class DCCHandler < Axial::Addon
      def initialize(bot)
        super

        @name         = 'dcc handler'
        @author       = 'sylence <sylence@sylence.org>'
        @version      = '1.1.0'

        @port         = 54321

        on_dcc          'help',   :dcc_help
        on_dcc        'reload',   :reload_addons

        on_privmsg      'chat',   :send_dcc_chat_offer
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

      def send_dcc_chat_offer(nick, command)
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
          LOGGER.error("connection attempt timed out attempting to dcc chat #{nick.name} (#{user.pretty_name})")
        end
        
        tcp_server.close
        if (!socket.nil?)
          socket.puts("Hello #{user.pretty_name}.")
          auth = false
          while (text = socket.gets)
            text.strip!
            bind_handler.dispatch_dcc_binds(user, socket, text)
          end
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
