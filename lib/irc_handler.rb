$:.unshift(File.expand_path(File.join(File.dirname('.'), 'lib')))
$stdout.sync = true
$stderr.sync = true

require 'yaml'
require 'timeout'
require 'socket'

require 'colors.rb'
require 'channel.rb'
require 'command.rb'
require 'constants.rb'
require 'addon.rb'
require 'log.rb'
require 'underscore.rb'

# handlers...need eventing
require 'handlers/server_handler.rb'
require 'handlers/message_handler.rb'

# move to an addon?
require 'models/init.rb'

class AccessDenied < StandardError
end

module Axial
  class IRCHandler
#    include Singleton
    include Axial::Handlers::ServerHandler
    include Axial::Handlers::MessageHandler
    def initialize(props_file)
      @addons              = []
      @binds               = []
      @bot_running         = true
      @channels            = {}
      @connected_to_server = false
      @props_file          = props_file
      @real_server_name    = ""
      @server_detected     = false
      @serverconn          = nil
      load_props
    end

    def load_props()
      props = YAML.load_file(File.join(File.dirname(__FILE__), '..', @props_file))
      @server_name    = props['server']['name']     || 'irc.efnet.org'
      @server_port    = props['server']['port']     || 6667
      @server_timeout = props['server']['timeout']  || 10
      @ssl            = props['server']['ssl']      || false
      @bot_nick       = props['bot']['nick']        || 'unnamed'
      @bot_realname   = props['bot']['real_name']   || 'unnamed'
      @bot_user       = props['bot']['user_name']   || 'unnamed'
      @addon_list     = props['addons']             || []
      @autojoin       = props['channels']
    end

    def send_raw(cmd)
      if (!cmd =~ /^PONG /)
        LOGGER.debug("Sent to server: #{cmd}")
      end
      @serverconn.puts(cmd)
    end

    def reload_addons()
      load_props
      load_addons
    end

    def load_addons()
      if (@addon_list.count == 0)
        LOGGER.debug("No addons specified.")
      else
        @addon_list.each do |addon|
          load File.join(File.dirname(__FILE__), '..', 'addons', "#{addon.underscore}.rb")
          addon_object = Object.const_get("Axial::Addons::#{addon}").new
          addon_object.irc = self
          @addons.push({name: addon_object.name, version: addon_object.version, author: addon_object.author, object: addon_object})
          addon_object.listeners.each do |listener|
            @binds.push(type: listener[:type], object: addon_object, command: listener[:command], method: listener[:method].to_sym)
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
  
          # TODO: create state tracking for server in an enum
          # TODO: change to case with handlers
          while (raw_server_msg = @serverconn.readline)
            raw_server_msg.chomp!
              
            # this definitely needs to be improved
            if (!@server_detected && raw_server_msg =~ /^:\S+ 004 #{@bot_nick} (\S+)/)
              @real_server_name = $1
              @server_detected = true
              LOGGER.info("actual server host: #{@real_server_name}")
              next
            elsif (raw_server_msg =~ /^:#{@real_server_name} 376/ || raw_server_msg =~ /^#{@real_server_name} 422/)
              # TODO : better parsing and joining
              LOGGER.info("end of motd")
              @autojoin.each do |channel_name|
                join_channel(channel_name)
              end
              next
            elsif (raw_server_msg =~ /^:#{@real_server_name} 375:{0,1}\s+(.*)/)
              LOGGER.info("begin motd")
              next
            elsif (raw_server_msg =~ /^:#{@real_server_name} 372:{0,1}\s+(.*)/)
              LOGGER.info("motd: " + Regexp.last_match[1])
              next
            elsif (raw_server_msg =~ /^PING (.*)/)
              handle_server_ping(Regexp.last_match[1])
              next
            elsif (raw_server_msg =~ /^ERROR :(.*)/)
              handle_server_error(Regexp.last_match[1])
              next
            elsif (raw_server_msg =~ /^:(\S+) JOIN :{0,1}(\S+)/)
              nick = Axial::Nick.from_uhost(self, Regexp.last_match[1])
              channel_name = Regexp.last_match[2]
              if (nick.name.casecmp(@bot_nick).zero?)
                handle_self_join(channel_name)
                # TODO: critical section around channel join
              else
                channel = @channels[channel_name]
                # TODO: critical section around channel join
                LOGGER.debug("#{nick.uhost} joined #{channel.name}")
                handle_join(channel, nick)
              end
              next
            elsif (raw_server_msg =~ /^:(\S+) PART (\S+)(.*)/)
              nick = Axial::Nick.from_uhost(self, Regexp.last_match[1])
              channel = Axial::Channel.new(self, Regexp.last_match[2])
              reason = Regexp.last_match[3].strip
              if (reason =~ /^:(.*)/)
                reason = Regexp.last_match[1].strip
              end

              if (nick.name.casecmp(@bot_nick).zero?)
                handle_self_part(channel)
              else
                if (reason.empty?)
                  LOGGER.debug("#{nick.uhost} left #{channel.name}")
                  handle_part(channel, nick, reason)
                else
                  LOGGER.debug("#{nick.uhost} left #{channel.name} (#{reason})")
                  handle_part(channel, nick, reason)
                end
              end
              next
            elsif (raw_server_msg =~ /^:(\S+) QUIT(.*)/)
              nick = Axial::Nick.from_uhost(self, Regexp.last_match[1])
              reason = Regexp.last_match[2].strip
              if (reason =~ /^:(.*)/)
                reason = Regexp.last_match[1].strip
              end

              if (nick.name.casecmp(@bot_nick).zero?)
                # this is not how a client is told they're quitting...
                # [   unhandled    ] Closing Link: axial[localhost] (Quit: axial)
                # [       log      ] lost connection to server - EOFError: end of file reached
                handle_self_quit(reason)
              else
                if (reason.empty?)
                  LOGGER.debug("#{nick.uhost} quit IRC")
                  handle_quit(nick, reason)
                else
                  LOGGER.debug("#{nick.uhost} quit IRC (#{reason})")
                  handle_quit(nick, reason)
                end
              end
              next
            elsif (raw_server_msg =~ /^NOTICE \S+ :(.*)/)
              handle_server_notice(Regexp.last_match[1])
              next
            elsif (raw_server_msg =~ /^:(\S+) PRIVMSG (\S+) :(.*)/)
              nick = Axial::Nick.from_uhost(self, Regexp.last_match[1])
              dest = Regexp.last_match[2]
              msg = Regexp.last_match[3]
              if (dest.start_with?("#"))
                if (@channels.has_key?(dest.downcase))
                  channel = @channels[dest.downcase]
                else
                  raise(RuntimeError, "No channel object for #{dest}")
                 # channel = Axial::Channel.new(self, dest)
                 # @channels[dest] = channel
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

              if (uhost.casecmp(@server_name).zero? || uhost == @real_server_name || !uhost.include?('!'))
                handle_server_notice(msg)
                next
              end

              nick = Axial::Nick.from_uhost(self, uhost)
              if (dest.start_with?("#"))
                if (@channels.has_key?(dest))
                  channel = @channels[dest]
                else
                  raise(RuntimeError, "No channel object for #{dest}")
                 # channel = Axial::Channel.new(self, dest)
                 # @channels[dest] = channel
                end
                handle_channel_notice(channel, nick, msg)
              else
                handle_notice(nick, msg)
              end
              next
            else
              LOGGER.warn("unhandled: #{raw_server_msg}")
              next
            end
          end
        rescue Errno::ECONNRESET => ex
          LOGGER.error("lost connection to server - #{ex.class}: #{ex.message}")
          @connected_to_server = false
          sleep 5
        rescue EOFError => ex
          LOGGER.error("lost connection to server - #{ex.class}: #{ex.message}")
          @connected_to_server = false
          sleep 5
        end
      end
    end
  end
end

