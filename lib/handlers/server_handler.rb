module Axial
  module Handlers
    module ServerHandler
      def connect_to_server(ssl = false)
        begin
          Timeout::timeout(@server_timeout) do
            log "connecting to #{@connect_address}:#{@server_port}"
            if (ssl)
              context = OpenSSL::SSL::SSLContext::new
              context.verify_mode = OpenSSL::SSL::VERIFY_NONE
              tcp_socket = ::TCPSocket.new(@connect_address, @server_port)
              @serverconn = OpenSSL::SSL::SSLSocket::new(tcp_socket, context)
              @serverconn.connect
            else
              @serverconn = ::TCPSocket.new(@connect_address, @server_port)
            end
          end
          log "connected to #{@connect_address}:#{@server_port}"
          @connected_to_server = true
        rescue SocketError => ex
          log "#{ex.class}: #{ex.message}"
          sleep 15
          retry
        rescue Timeout::Error => ex
          log "Unable to connect - connection attempt timed out."
          sleep 15
          retry
        rescue Errno::ECONNREFUSED => ex
          log "Unable to connect - connection refused. (#{ex.message})"
          sleep 15
          retry
        end
      end

      def handle_self_join(channel)
        log "I joined #{channel.name}"
      end

      def handle_join(channel, nick)
        @join_binds.each do |bind|
          bind[:object].send(bind[:method], channel, nick)
        end
      end

      def send_login_info()
        send_raw "USER #{@bot_user} 0 * :#{@bot_realname}"
        send_raw "NICK #{@bot_nick}"
        log "logged in to server"
      end

      def join_channel(channel)
        send_raw "JOIN #{channel}"
      end

      def send_privmsg(nick, message)
        send_raw "PRIVMSG #{nick} :#{message}"
        sleep 1
      end

      def send_channel(channel, message)
        send_raw "PRIVMSG #{channel} :#{message}"
        sleep 1
      end
  
      def handle_server_ping(response)
        send_raw "PONG #{response}"
      end
  
      def handle_server_notice(msg)
        log_server_notice(msg)
      end
  
      def set_channel_mode(channel_name, mode)
        send_raw "MODE #{channel_name} #{mode}"
      end

      def handle_server_error(error)
        puts "\e[01;31m[  server error  ]\e[00m #{error}"
      end
  
      def handle_server_error(error)
        log_server_error(error)
      end
    end
  end
end
