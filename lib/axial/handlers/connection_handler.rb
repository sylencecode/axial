$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname('.'), 'lib')))
$stdout.sync = true
$stderr.sync = true

require 'socket'
require 'timeout'
require 'openssl'
require 'axial/irc_types/server'
require 'axial/consumers/chat_consumer'
require 'axial/consumers/raw_consumer'

module Axial
  module Handlers
    class ConnectionHandler
      attr_reader :server, :raw_consumer, :chat_consumer

      def initialize(bot, server)
        @server          = server
        @bot             = bot
        @send_monitor    = Monitor.new
        @raw_consumer    = Consumers::RawConsumer.new
        @chat_consumer   = Consumers::ChatConsumer.new
        @raw_consumer.register_callback(self, :direct_send)
        @chat_consumer.register_callback(self, :direct_send)
      end

      def connect()
        @bot.server_interface.myself = IRCTypes::Nick.new(@bot.server_interface)
        @bot.server_interface.myself.name = @bot.real_nick
        @raw_consumer.start
        @chat_consumer.start
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
      rescue OpenSSL::SSL::SSLError => ex
        LOGGER.error("cannot connect to #{@server.address} via ssl: #{ex.class}: #{ex.message}")
        LOGGER.info("reconnecting in 30 seconds...")
        sleep 30
        retry
      rescue Exception => ex
        LOGGER.error("unhandled connection error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
        LOGGER.info("reconnecting in 30 seconds...")
        sleep 30
        retry
      end
      private :connect

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

      def login()
        direct_send("USER #{@bot.user} 0 * :#{@bot.real_name}")
        direct_send("NICK #{@bot.real_nick}")
        LOGGER.info("sent credentials to server")
      end
      private :login

      def pong(ping)
        direct_send("PONG #{ping}")
      end
      private :pong

      def dispatch(raw)
        if (raw =~ /^:(\S+)\s+001\s+#{@bot.real_nick}/)
          @server.real_address = Regexp.last_match[1]
          LOGGER.info("actual server host: #{@server.real_address}")
          @bot.server_consumer.send(raw)
        elsif (raw =~ /^PING\s+(.*)/)
          pong(Regexp.last_match[1])
        else
          @bot.server_consumer.send(raw)
        end
      end
      private :dispatch

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
