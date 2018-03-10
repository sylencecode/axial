module Axial
  module Handlers
    module Logging
      def log(msg)
        puts "\e[01;34m[       log      ]\e[00m #{msg}"
      end
  
      def log_privmsg(nick, msg)
        puts "\e[01;31m[    priv msg    ]\e[00m <#{nick}> #{msg}"
      end
  
      def log_channel_message(nick, channel, msg)
        puts "\e[01;36m[    chan msg    ]\e[00m #{channel} <#{nick}> #{msg.inspect}"
      end
  
      def log_notice(nick, msg)
        puts "\e[01;35m[  priv notice   ]\e[00m <#{nick}> #{msg}"
      end
  
      def log_channel_notice(nick, channel, msg)
        puts "\e[01;35m[  chan notice   ]\e[00m #{channel} <#{nick}> #{msg}"
      end
  
      def log_server_notice(msg)
        puts "\e[01;35m[  server notice ]\e[00m #{msg}"
      end
  
      def log_server(msg)
        puts "\e[01;30m[   raw server   ]\e[00m #{msg}"
      end
  
      def log_outbound(msg)
        puts "\e[01;32m[  to server --> ]\e[00m #{msg}"
      end
  
      def log_server_error(raw_server_msg)
        puts "\e[01;31m[   unhandled    ]\e[00m #{raw_server_msg}"
      end
  
      def log_unhandled(raw_server_msg)
        puts "\e[01;31m[   unhandled    ]\e[00m #{raw_server_msg}"
      end
  
      def log_quit (nick, reason)
        puts "\e[01;30m[      quit      ]\e[00m #{nick} - #{reason}"
      end
    end
  end
end
