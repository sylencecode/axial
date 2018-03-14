require 'uri'

$irc_gray = "\x0314"
$irc_reset = "\x03"
$irc_blue = "\x0312"
$irc_darkblue = "\x032"
$irc_darkcyan = "\x0310"
$irc_cyan = "\x0311"
$irc_red = "\x034"
$irc_darkred = "\x035"
$irc_yellow = "\x038"
$irc_green = "\x039"
$irc_darkgreen = "\x033"
$irc_magenta = "\x0313"
$irc_darkmagenta = "\x036"

module Axial
  module Handlers
    module MessageHandler
      def handle_notice(nick, msg)
        log_notice(nick.name, msg)
      end
  
      def handle_privmsg(nick, msg)
        log_privmsg(nick.name, msg)
        if (msg =~ /exec (.*)/)
          command = Regexp.last_match[1].strip
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            nick.message(Constants::ACCESS_DENIED)
            return
          end
          nick.message("sending command: #{command}")
          send_raw(command)
        end
      end
  
      # TODO: construct these objects sooner...
      def handle_channel_message(channel, nick, msg)
        blacklist = [ "howto", "lockie" ]
        if (msg =~ /^\x01ACTION/)
          return
        elsif (blacklist.include?(nick.name.downcase))
          return
        end

        msg.strip!
        if (msg.empty?)
          return
        end

        log_channel_message(nick.name, channel.name, msg)

        if (msg.downcase =~ /^\?about$/ || msg.downcase =~ /^\?help$/)
          channel.message("#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR}")
          if (@addons.count > 0)
            @addons.each do |addon|
              channel_listeners = addon[:object].listeners.select{|listener| listener[:type] == :channel}
              listener_string = ""
              if (channel_listeners.count > 0)
                commands = channel_listeners.collect{|foo| foo[:command]}
                listener_string = " (" + commands.join(', ') + ")"
              end
              channel.message(" + #{addon[:name]} version #{addon[:version]} by #{addon[:author]}#{listener_string}")
            end
          end
          return
        end

        @binds.select{|bind| bind[:type] == :channel}.each do |bind|
          begin
            match = '^(' + Regexp.escape(bind[:command]) + ')'
            base_match = match + '$'
            args_match = match + '\s+(.*)'
            args_regexp = Regexp.new(args_match, true)
            base_regexp = Regexp.new(base_match, true)
            # crummy way to avoid building objects for every message 
            if (msg =~ args_regexp)
              command = Regexp.last_match[1]
              args = Regexp.last_match[2]
              command_object = ::Axial::Command.new(command, args)
              bind[:object].send(bind[:method], channel, nick, command_object)
            elsif (msg =~ base_regexp)
              command = Regexp.last_match[1]
              args = ""
              command_object = ::Axial::Command.new(command, args)
              bind[:object].send(bind[:method], channel, nick, command_object)
            end
          rescue Exception => ex
            log "#{self.class} error: #{ex.class}: #{ex.message}"
            ex.backtrace.each do |i|
              log i
            end
          end
        end

#         elsif (msg =~ /^\?s (.*)/ || msg =~/^\?seen (\S+)/)
#           seen_nick = $1.strip
#           if (!seen_nick.empty?)
#             handle_seen(nick, channel, seen_nick)
#           end
#         elsif (msg =~ /(https:\/\/youtu\.be\/\S+)/ || msg =~ /(https:\/\/www\.youtube\.com\/\S+)/ || msg =~ /(https:\/\/m\.youtube\.com\/\S+)/)
#           uri = $1
#           handle_youtube(nick, channel, uri)
#         elsif (msg.scan(URI.regexp).count > 0)
#           #send_channel(channel, "#{nick}: that has a url")
#         else
#           # handle any other like global binds this way
#           handle_markov(nick, channel, msg)
#         end
      end
  
      def handle_channel_notice(nick, channel, msg)
        log_channel_notice(nick.name, channel.name, msg)
      end 
    end
  end
end
