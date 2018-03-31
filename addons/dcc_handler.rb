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

        on_privmsg    'chatto',     :send_dcc_chat_offer
      end

      def send_dcc_chat_offer(nick, command)
        local_ip    = Resolv.getaddress(Socket.gethostname)

        user = user_list.get_from_nick_object(nick)
        if (user.nil? || !user.director?)
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
    end
  end
end
