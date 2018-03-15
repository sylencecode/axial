require 'uri'

module Axial
  module Handlers
    module MessageHandler
      def handle_notice(nick, msg)
        LOGGER.info("#{nick.name} NOTICE: #{msg}")
      end
  
      def handle_privmsg(nick, msg)
        LOGGER.info("#{nick.name} PRIVMSG: #{msg}")
        if (msg =~ /exec (.*)/)
          command = Regexp.last_match[1].strip
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
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

        LOGGER.debug("CHANNEL #{channel.name}: <#{nick.name}> #{msg}")

        if (msg.downcase =~ /^\?about$/ || msg.downcase =~ /^\?help$/)
          channel.message("#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR}")
          if (@addons.count > 0)
            @addons.each do |addon|
              channel_listeners = addon[:object].listeners.select{|listener| listener[:type] == :channel && listener[:command].is_a?(String)}
              listener_string = ""
              if (channel_listeners.count > 0)
                commands = channel_listeners.collect{|foo| foo[:command]}
                listener_string = " (" + commands.join(', ') + ")"
              end
              channel.message(" + #{addon[:name]} version #{addon[:version]} by #{addon[:author]}#{listener_string}")
            end
          end
          return
        elsif (msg.downcase =~ /^\?reload$/)
          begin
            user_model = Models::User.get_from_nick_object(nick)
            if (user_model.nil?)
              nick.message(Constants::ACCESS_DENIED)
              return
            end
            if (@addons.count == 0)
              channel.message("#{nick.name}: No addons loaded...")
              return
            end

            channel.message("unloading addons: #{@addons.collect{|addon| addon[:name]}.join(', ')}")
            classes_to_unload = []
            @addons.each do |addon|
              class_name = addon[:object].class.to_s.split('::').last
              classes_to_unload.push(class_name)
              if (addon[:object].respond_to?(:before_reload))
                addon[:object].public_send(:before_reload)
              end
            end

            @binds.clear
            @addons.clear

            classes_to_unload.each do |class_name|
              LOGGER.debug("removing class definition for #{class_name}")
              if (Object.constants.include?(:Axial))
                if (Axial.constants.include?(:Addons))
                  if (Axial::Addons.constants.include?(class_name.to_sym))
                    Axial::Addons.send(:remove_const, class_name.to_sym)
                  end
                end
              end
            end

            load_addons

            channel.message("loaded addons: #{@addons.collect{|addon| addon[:name]}.join(', ')}")
          rescue Exception => ex
            LOGGER.error("addon reload error: #{ex.class}: #{ex.message}")
            ex.backtrace.each do |i|
              LOGGER.error(i)
            end
          end
          return
        end

        @binds.select{|bind| bind[:type] == :channel}.each do |bind|
          begin
            if (bind[:command].is_a?(String))
              match = '^(' + Regexp.escape(bind[:command]) + ')'
              base_match = match + '$'
              args_match = match + '\s+(.*)'
              # this is done to ensure that a command is typed in its entirety, even if it had no arguments
              args_regexp = Regexp.new(args_match, true)
              base_regexp = Regexp.new(base_match, true)
              if (msg =~ args_regexp)
                command = Regexp.last_match[1]
                args = Regexp.last_match[2]
                command_object = Axial::Command.new(command, args)
                Thread.new do
                  bind[:object].public_send(bind[:method], channel, nick, command_object)
                end
                break
              elsif (msg =~ base_regexp)
                command = Regexp.last_match[1]
                args = ""
                command_object = Axial::Command.new(command, args)
                Thread.new do
                  bind[:object].public_send(bind[:method], channel, nick, command_object)
                end
                break
              end
            elsif (bind[:command].is_a?(Regexp))
              if (msg =~ bind[:command])
                Thread.new do
                  bind[:object].public_send(bind[:method], channel, nick, msg)
                end
                break
              end
            else
              LOGGER.error("#{self.class}: unsure how to handle bind #{bind.inspect}, it isn't a string or regexp.")
            end
          rescue Exception => ex
            LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
            ex.backtrace.each do |i|
              LOGGER.error(i)
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
        LOGGER.info("#{nick.name} NOTICE #{channel.name}: #{msg}")
      end 
    end
  end
end
