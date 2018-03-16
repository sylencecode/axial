module Axial
  module Handlers
    module ServerHandler
      def connect_to_server(ssl = false)
        begin
          Timeout::timeout(@connect_timeout) do
            LOGGER.info("connecting to #{@server_name}:#{@server_port}")
            if (ssl)
              context = OpenSSL::SSL::SSLContext::new
              context.verify_mode = OpenSSL::SSL::VERIFY_NONE
              tcp_socket = ::TCPSocket.new(@server_name, @server_port)
              @serverconn = OpenSSL::SSL::SSLSocket::new(tcp_socket, context)
              @serverconn.connect
            else
              @serverconn = ::TCPSocket.new(@server_name, @server_port)
            end
          end
          LOGGER.info("connected to #{@server_name}:#{@server_port}")
          @connected_to_server = true
        rescue SocketError => ex
          LOGGER.error("#{ex.class}: #{ex.message}")
          sleep @connect_timeout
          retry
        rescue Timeout::Error => ex
          LOGGER.error("unable to connect - connection attempt timed out - trying again in 15 seconds.")
          sleep @connect_timeout
          retry
        rescue Errno::ECONNREFUSED => ex
          LOGGER.error("unable to connect - connection refused - trying again in 15 seconds.")
          sleep @connect_timeout
          retry
        end
      end

      def handle_self_part(channel)
        if (@channels.has_key?(channel.name.downcase))
          @channels.delete(channel.name.downcase)
        end
        LOGGER.debug("i left #{channel.name}")
        @binds.select{|bind| bind[:type] == :self_part}.each do |bind|
          bind[:object].public_send(bind[:method], channel)
        end
      end

      def handle_part(channel, nick, reason)
        @binds.select{|bind| bind[:type] == :part}.each do |bind|
          bind[:object].public_send(bind[:method], channel, nick, reason)
        end
      end

      def handle_quit(nick, reason)
        # remove nick from channels
        @binds.select{|bind| bind[:type] == :quit}.each do |bind|
          bind[:object].public_send(bind[:method], nick, reason)
        end
        LOGGER.debug("#{nick.uhost} left IRC (#{reason})")
      end

      def handle_self_quit(reason)
        # need to come up with other reasons why channel list should be cleared
        @channels.clear
        if (reason.empty?)
          LOGGER.debug("i quit irc")
        else
          LOGGER.debug("I quit IRC (#{reason})")
        end
      end

      def handle_self_join(channel_name)
        LOGGER.info("i joined #{channel_name}")
        if (!@channels.has_key?(channel_name.downcase))
          channel = Axial::Channel.new(self, channel_name)
          @channels[channel_name.downcase] = channel
        end
        # TODO: these binds should probably not be called until after the join is synced
        # could add a mutex here and wait for the sync before proceeding
        @binds.select{|bind| bind[:type] == :self_join}.each do |bind|
          Thread.new do
            begin
              bind[:object].public_send(bind[:method], channel)
            rescue Exception => ex
              # TODO: move this to an addon handler
              channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      end

      def handle_join(channel, nick)
        @binds.select{|bind| bind[:type] == :join}.each do |bind|
          Thread.new do
            begin
              bind[:object].public_send(bind[:method], channel, nick)
            rescue Exception => ex
              # TODO: move this to an addon handler
              channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      end

      def send_login_info()
        send_raw "USER #{@bot_user} 0 * :#{@bot_realname}"
        send_raw "NICK #{@bot_nick}"
        LOGGER.info("sent credentials to server")
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
        LOGGER.info("SERVER NOTICE: #{msg}")
      end
  
      def set_channel_mode(channel_name, mode)
        send_raw "MODE #{channel_name} #{mode}"
      end

      def handle_server_error(error)
        LOGGER.error("SERVER ERROR: #{error}")
      end
    end
  end
end
