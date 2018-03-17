require 'socket'
require 'timeout'
require 'openssl'
require 'server'
require 'consumers/chat_consumer'
require 'consumers/raw_consumer'

module Axial
  module Handlers
    class ServerHandler
      attr_reader :server, :raw_consumer, :chat_consumer

      def initialize(bot, server)
        @server_detected = false
        @server          = server
        @bot             = bot
        @send_monitor    = Monitor.new
        @raw_consumer    = Consumers::RawConsumer.new(self, :send)
        @chat_consumer   = Consumers::ChatConsumer.new(self, :send)
      end

      def connect()
        @raw_consumer.start
        @chat_consumer.start
        @real_server_name = ''
        LOGGER.info("connecting to #{@server.address}:#{@server.port} (ssl: #{@server.ssl?})")
          Timeout.timeout(@connect_timeout) do
          if (@server.ssl?)
            context = OpenSSL::SSL::SSLContext::new
            context.verify_mode = OpenSSL::SSL::VERIFY_NONE
            tcp_socket = ::TCPSocket.new(@server.address, @server.port)
            @conn = OpenSSL::SSL::SSLSocket::new(tcp_socket, context)
            @conn.connect
          else
            @conn = TCPSocket.new(@server.address, @server.port)
          end
        end

        LOGGER.info("connected to #{@server.address}:#{@server.port}")
        @connected = true
      end
      private :connect

      def send(raw)
        @send_monitor.synchronize do
          @conn.puts(raw)
          if (!raw =~ /^PONG /)
            LOGGER.debug("Sent to server: #{cmd}")
          end
        end
      end

      def login()
        send("USER #{@bot.bot_user} 0 * :#{@bot.bot_realname}")
        send("NICK #{@bot.bot_nick}")
        LOGGER.info("sent credentials to server")
      end

      def pong(ping)
        send("PONG #{ping}")
      end

      def dispatch(raw)
        if (raw =~ /^:(\S+)\s+001\s+#{@bot.bot_nick}/)
          @real_server_name = Regexp.last_match[1]
          @server_detected = true
          LOGGER.info("actual server host: #{@real_server_name}")
        elsif (raw =~ /^PING\s+(.*)/)
          pong(Regexp.last_match[1])
        else
          @bot.server_consumer.send(raw)
        end
      end

      def autojoin_channels()
        LOGGER.info("reached end of MOTD, processing on-connect hooks")
        @bot.autojoin.each do |channel|
          join(channel)
        end
      end

      def dispatch_numeric(code, text)
        case code
          when '376', '422'
            autojoin_channels
          when '315'
            # end of /who list, free up the channel and call it sync'd
          when '352'
            # start putting nicks and uhosts in
          when '353'
            # lock the mutex on
            # got names list, start channel
          when '366'
            # names list is over, perform WHO #channel
          else
            LOGGER.info("[unh #{code}] #{text}")
        end
      end

      def join(channel, password = "")
        if (password.empty?)
          send("JOIN #{channel}")
        else
          send("JOIN #{channel} #{password}")
        end
      end

      def loop()
        connect
        login
        while (raw = @conn.readline)
          dispatch(raw.chomp)
        end
      rescue SocketError => ex
        LOGGER.error("#{ex.class}: #{ex.message}")
        sleep @server.timeout
        retry
      rescue Timeout::Error => ex
        LOGGER.error("unable to connect - connection attempt timed out - trying again in 15 seconds.")
        sleep @server.timeout
        retry
      rescue Errno::ECONNREFUSED => ex
        LOGGER.error("unable to connect - connection refused - trying again in 15 seconds.")
        sleep @server.timeout
        retry
      end
    end
  end
end

module Unused
  module Unused2
    module Unused3
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

      def send_privmsg(nick, message)
        send_raw "PRIVMSG #{nick} :#{message}"
        sleep 1 
      end

      def send_channel(channel, message)
        send_raw "PRIVMSG #{channel} :#{message}"
        sleep 1
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
