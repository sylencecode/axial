require 'socket'
require 'timeout'
require 'openssl'
require 'axial/irc_types/server'
require 'axial/consumers/chat_consumer'
require 'axial/consumers/raw_consumer'

module Axial
  module Handlers
    class ConnectionHandler
      attr_reader :server, :raw_consumer, :chat_consumer, :regaining_nick

      def initialize(bot, server)
        @server                 = server
        @server_connect_timeout = 15
        @bot                    = bot
        @send_monitor           = Monitor.new
        @raw_consumer           = Consumers::RawConsumer.new
        @chat_consumer          = Consumers::ChatConsumer.new
        @uhost_timer            = nil
        @auto_join_timer        = nil
        @nick_regain_timer      = nil
        @regaining_nick         = false
        @raw_consumer.register_callback(self, :direct_send)
        @chat_consumer.register_callback(self, :direct_send)
      end

      def handle_disconnect_cleanup()
        @bot.trying_nick    = @bot.nick
        @regaining_nick     = false
        @server.connected   = false

        @bot.timer.delete(@uhost_timer)
        @bot.timer.delete(@auto_join_timer)
        @bot.timer.delete(@nick_regain_timer)
        @bot.server_interface.cancel_pending_joins
        @bot.server_interface.channel_list.clear
        @bot.bind_handler.dispatch_server_disconnect_binds
      end

      def connect()
        @bot.server_interface.myself = IRCTypes::Nick.new(@bot.server_interface)
        @bot.server_interface.myself.name = @bot.real_nick
        @raw_consumer.start
        @chat_consumer.start
        LOGGER.info("connecting to #{@server.address}:#{@server.port} (ssl: #{@server.ssl?})")
        Timeout.timeout(@server_connect_timeout) do
          if (@server.ssl?)
            context = OpenSSL::SSL::SSLContext.new
            context.verify_mode = OpenSSL::SSL::VERIFY_NONE
            tcp_socket = ::TCPSocket.new(@server.address, @server.port)
            @conn = OpenSSL::SSL::SSLSocket.new(tcp_socket, context)
            @conn.connect
          else
            @conn = TCPSocket.new(@server.address, @server.port)
          end
        end
        LOGGER.info("established tcp connection with #{@server.address}:#{@server.port}")
      rescue OpenSSL::SSL::SSLError => ex
        LOGGER.error("cannot connect to #{@server.address} via ssl: #{ex.class}: #{ex.message}")

        handle_disconnect_cleanup
        LOGGER.info("reconnecting in #{@server.reconnect_delay} seconds...")
        sleep @server.reconnect_delay
        retry
      rescue Timeout::Error => ex
        LOGGER.error("connection attempt to #{@server.address}:#{@server.port} timed out, retrying...")
        sleep 1
        retry
      rescue Exception => ex
        LOGGER.error("unhandled connection error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end

        handle_disconnect_cleanup
        LOGGER.info("reconnecting in #{@server.reconnect_delay} seconds...")
        sleep @server.reconnect_delay
        retry
      end
      private :connect

      def nick_regained()
        @regaining_nick                   = false
        @bot.server_interface.myself.name = @bot.nick
        @bot.real_nick                    = @bot.nick

        @bot.timer.delete(@nick_regain_timer)
        LOGGER.debug("regained original nick: #{@bot.nick}")
      end

      def send_chat(raw)
        @chat_consumer.send(raw)
      end

      def send_raw(raw)
        @raw_consumer.send(raw)
      end

      def direct_send(raw)
        @send_monitor.synchronize do
          @conn.puts(raw)
          if (raw !~ /^PONG /)
            LOGGER.debug(" --> #{raw}")
          end
        end
      end

      def try_nick()
        direct_send("NICK #{@bot.trying_nick}")
      end

      def login()
        direct_send("USER #{@bot.user} 0 * :#{@bot.real_name}")
        try_nick
        LOGGER.info('sent credentials to server')
      end
      private :login

      def pong(ping)
        direct_send("PONG #{ping}")
      end
      private :pong

      def dispatch(raw)
        if (raw =~ /^:(\S+)\s+001\s+(#{@bot.trying_nick})/)
          @server.real_address = Regexp.last_match[1]
          @server.connected = true
          if (!@bot.trying_nick.casecmp(@bot.nick).zero?)
            @regaining_nick = true
            @nick_regain_timer = @bot.timer.every_60_seconds(@bot.server_interface, :send_ison)
          end
          @bot.real_nick = @bot.trying_nick
          @bot.server_interface.myself.name = @bot.real_nick
          LOGGER.info("actual nick: #{@bot.real_nick}")
          LOGGER.info("actual server host: #{@server.real_address}")
          @bot.server_consumer.send(raw)
          @uhost_timer = @bot.timer.every_minute do
            if (@bot.server_interface.myself.uhost.empty?)
              @bot.server_interface.whois_myself
            end
          end
          @auto_join_timer = @bot.timer.every_30_seconds(@bot.server_interface, :retry_joins)
        elsif (raw =~ /^PING\s+(.*)/)
          pong(Regexp.last_match[1])
        else
          @bot.server_consumer.send(raw)
        end
      end
      private :dispatch

      def loop()
        sleep 5
        connect
        login
        while (raw = @conn.readline)
          dispatch(raw.chomp)
        end
      rescue SocketError, Timeout::Error, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ENETDOWN, EOFError => ex
        LOGGER.error("lost server connection: #{ex.class}: #{ex.message}")

        handle_disconnect_cleanup
        LOGGER.info("reconnecting in #{@server.reconnect_delay} seconds...")
        sleep @server.reconnect_delay
        retry
      end
    end
  end
end
