$:.unshift(File.expand_path(File.join(File.dirname('.'), 'lib')))
require 'timeout'
require 'socket'

require 'channel.rb'
require 'command.rb'
require 'constants.rb'

# handlers...need eventing
require 'handlers/logging.rb'
require 'handlers/server_handler.rb'
require 'handlers/message_handler.rb'

# move to seen
# require 'timespan.rb'

# move to an addon?
require 'models/init.rb'
require 'models/nick.rb'
require 'models/mask.rb'
require 'models/seen.rb'

class AccessDenied < Exception
end

module Axial
  class Addon
    include Axial::Handlers::Logging
    attr_reader :listeners, :name, :version, :author

    def initialize()
      @listeners = []
      @name = "unnamed"
      @author = "unknown author"
      @version = "unknown version"
    end

    def on_channel(command, method)
      log "Channel command '#{command}' will invoke method '#{self.class}.#{method}'"
      @listeners.push(type: :channel, command: command, method: method)
    end

    def on_join(method)
      log "Channel join will invoke method '#{self.class}.#{method}'"
      @listeners.push(type: :join, method: method)
    end
  end
end

module Axial
  class IRCHandler
    include Axial::Handlers::Logging
    include Axial::Handlers::ServerHandler
    include Axial::Handlers::MessageHandler
    def initialize(connect_address, server_port, ssl = false)
      @server_name = connect_address
      @connect_address = connect_address
      @server_port = server_port
      @server_timeout = 10
      @serverconn = nil
      @connected_to_server = false
      @bot_nick = "axial"
      @bot_realname = "axial"
      @bot_user = "axial"
      @server_detected = false
      @bot_running = true
      @ssl = ssl
      @addons = []
      @addon_list = [
        { file: 'addons/auto_op.rb', class: 'Axial::Addons::AutoOp' },
        { file: 'addons/google_search.rb', class: 'Axial::Addons::GoogleSearch' },
        { file: 'addons/learner_of_things.rb', class: 'Axial::Addons::LearnerOfThings' },
        { file: 'addons/maga.rb', class: 'Axial::Addons::MakeAmericaGreatAgain' },
        { file: 'addons/weather.rb', class: 'Axial::Addons::Weather' },
        { file: 'addons/wikipedia.rb', class: 'Axial::Addons::Wikipedia' }
      ]
      @channel_binds = []
      @join_binds = []
      @channels = {}
    end

    def send_raw(cmd)
      if (!cmd =~ /^PONG /)
        log_outbound cmd
      end
      @serverconn.puts(cmd)
    end

    def load_addons()
      @addon_list.each do |addon|
        require addon[:file]
        addon_object = Object.const_get(addon[:class]).new
        @addons.push({name: addon_object.name, version: addon_object.version, author: addon_object.author, object: addon_object})
        addon_object.listeners.each do |listener|
          if (listener[:type] == :channel)
            @channel_binds.push(object: addon_object, command: listener[:command], method: listener[:method].to_sym)
          elsif (listener[:type] == :join)
            @join_binds.push(object: addon_object, method: listener[:method].to_sym)
          end
        end
      end
    end
    
    def run()
      load_addons
      while (@bot_running)
        begin
          while (!@connected_to_server)
            connect_to_server(@ssl)
            send_login_info
          end
  
          while (raw_server_msg = @serverconn.readline)
            raw_server_msg.chomp!
              
            # this definitely needs to be improved
            if (!@server_detected && raw_server_msg =~ /^:\S+ 004 #{@bot_nick} (\S+)/)
              @server_name = $1
              @server_detected = true
              log "actual server host: #{@server_name}"
              next
            elsif (raw_server_msg =~ /376/)
              log "got motd"
              join_channel "#lulz"
              next
            elsif (raw_server_msg =~ /^PING (.*)/)
              handle_server_ping(Regexp.last_match[1])
              next
            elsif (raw_server_msg =~ /^ERROR :(.*)/)
              handle_server_error(Regexp.last_match[1])
              next
            elsif (raw_server_msg =~ /^:(\S+) JOIN :{0,1}(\S+)/)
              nick = ::Axial::Nick.from_uhost(self, Regexp.last_match[1])
              channel = ::Axial::Channel.new(self, Regexp.last_match[2])
              if (nick.name.casecmp(@bot_nick).zero?)
                handle_self_join(channel)
              else
                log "#{nick.uhost} joined #{channel.name}"
                handle_join(channel, nick)
              end
              next
            elsif (raw_server_msg =~ /^:(\S+) QUIT :(.*)/)
              nick = ::Axial::Nick.from_uhost(self, Regexp.last_match[1])
              reason = Regexp.last_match[2]
              handle_quit(nick, reason)
              next
            elsif (raw_server_msg =~ /^NOTICE \S+ :(.*)/)
              handle_server_notice(Regexp.last_match[1])
              next
            elsif (raw_server_msg =~ /^:(\S+) PRIVMSG (\S+) :(.*)/)
              nick = ::Axial::Nick.from_uhost(self, Regexp.last_match[1])
              dest = Regexp.last_match[2]
              msg = Regexp.last_match[3]
              if (dest.start_with?("#"))
                if (@channels.has_key?(dest))
                  channel = @channels[dest]
                else
                  channel = ::Axial::Channel.new(self, dest)
                  @channels[dest] = channel
                end
                handle_channel_message(channel, nick, msg)
              else
                handle_privmsg(nick, msg)
              end
              next
            elsif (raw_server_msg =~ /^:(\S+) NOTICE (\S+) :(.*)/)
              uhost = Regexp.last_match[1]
              dest = Regexp.last_match[2]
              msg = Regexp.last_match[3]

              if (uhost == @server_name || !uhost.include?('!'))
                handle_server_notice(msg)
                next
              end

              nick = ::Axial::Nick.from_uhost(self, uhost)
              if (dest.start_with?("#"))
                if (@channels.has_key?(dest))
                  channel = @channels[dest]
                else
                  channel = ::Axial::Channel.new(self, dest)
                  @channels[dest] = channel
                end
                handle_channel_notice(channel, nick, msg)
              else
                handle_notice(nick, msg)
              end
              next
            else
              log_unhandled(raw_server_msg)
              next
            end
          end
        rescue Errno::ECONNRESET => e
          log "lost connection to server - #{e.class}: #{e.message}"
          @connected_to_server = false
          sleep 5
        rescue EOFError => e
          log "lost connection to server - #{e.class}: #{e.message}"
          @connected_to_server = false
          sleep 5
        end
      end
    end
  end
end

