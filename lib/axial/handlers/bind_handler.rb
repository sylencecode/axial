require 'axial/irc_types/command'

module Axial
  module Handlers
    class BindHandler

      def initialize(binds)
        @binds = binds
      end

      def dispatch_mode_binds(channel, nick, mode)
        @binds.select{|bind| bind[:type] == :mode}.each do |bind|
          Thread.new do
            begin
              if (bind[:modes].include?(:all) || (bind[:modes] & mode.channel_modes).any?)
                if (bind[:object].respond_to?(bind[:method]))
                  bind[:object].public_send(bind[:method], channel, nick, mode)
                else
                  LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                end
              end
            rescue Exception => ex
              channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_quit_binds(nick, reason)
        @binds.select{|bind| bind[:type] == :quit}.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                bind[:object].public_send(bind[:method], nick, reason)
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
              channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_part_binds(channel, nick, reason)
        @binds.select{|bind| bind[:type] == :part}.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                bind[:object].public_send(bind[:method], channel, nick, reason)
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
              channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_nick_change_binds(old_nick, new_nick)
        @binds.select{|bind| bind[:type] == :nick_change}.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                bind[:object].public_send(bind[:method], old_nick, new_nick)
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
              channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_channel_sync_binds(channel)
        @binds.select{|bind| bind[:type] == :channel_sync}.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                bind[:object].public_send(bind[:method], channel)
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
              channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end


      def dispatch_join_binds(channel, nick)
        @binds.select{|bind| bind[:type] == :join}.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                bind[:object].public_send(bind[:method], channel, nick)
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
              channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_channel_binds(channel, nick, text)
        @binds.select{|bind| bind[:type] == :channel}.each do |bind|
          if (bind[:object].throttle_secs > 0)
            if ((Time.now - bind[:object].last) < bind[:object].throttle_secs)
              next
            else
              bind[:object].last = Time.now
            end
          end
          if (bind[:command].is_a?(String))
            match = '^(' + Regexp.escape(bind[:command]) + ')'
            base_match = match + '$'
            args_match = match + '\s+(.*)'
            # this is done to ensure that a command is typed in its entirety, even if it had no arguments
            args_regexp = Regexp.new(args_match, true)
            base_regexp = Regexp.new(base_match, true)
            if (text =~ args_regexp)
              command, args = Regexp.last_match.captures
              command_object = IRCTypes::Command.new(command, args)
              Thread.new do
                begin
                  bind[:object].public_send(bind[:method], channel, nick, command_object)
                rescue Exception => ex
                  # TODO: move this to an addon handler
                  channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            elsif (text =~ base_regexp)
              command = Regexp.last_match[1]
              args = ""
              command_object = IRCTypes::Command.new(command, args)
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    bind[:object].public_send(bind[:method], channel, nick, command_object)
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  # TODO: move this to an addon handler
                  channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            end
          elsif (bind[:command].is_a?(Regexp))
            if (text =~ bind[:command])
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    bind[:object].public_send(bind[:method], channel, nick, text)
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  # TODO: move this to an addon handler
                  channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            end
          else
            LOGGER.error("#{self.class}: unsure how to handle bind #{bind.inspect}, it isn't a string or regexp.")
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end


      def dispatch_privmsg_binds(nick, text)
        @binds.select{|bind| bind[:type] == :privmsg}.each do |bind|
          puts "checking #{bind[:command]}"
          if (bind[:object].throttle_secs > 0)
            if ((Time.now - bind[:object].last) < bind[:object].throttle_secs)
              puts "time throttle"
              next
            end
          end
          puts "proceeding: #{bind[:command]}"
          if (bind[:command].is_a?(String))
            puts "a string: #{bind[:command].inspect}"
            match = '^(' + Regexp.escape(bind[:command]) + ')'
            base_match = match + '$'
            args_match = match + '\s+(.*)'
            # this is done to ensure that a command is typed in its entirety, even if it had no arguments
            args_regexp = Regexp.new(args_match, true)
            base_regexp = Regexp.new(base_match, true)
            puts text.inspect + "|" + args_regexp.source
            if (text =~ args_regexp)
              bind[:object].last = Time.now
              puts "main"
              command, args = Regexp.last_match.captures
              command_object = IRCTypes::Command.new(command, args)
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    bind[:object].public_send(bind[:method], nick, command_object)
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  # TODO: move this to an addon handler
                  nick.message("#{self.class} error: #{ex.class}: #{ex.message}")
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            elsif (text =~ base_regexp)
              bind[:object].last = Time.now
              puts "else"
              command = Regexp.last_match[1]
              args = ""
              command_object = IRCTypes::Command.new(command, args)
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    bind[:object].public_send(bind[:method], nick, command_object)
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  # TODO: move this to an addon handler
                  nick.message("#{self.class} error: #{ex.class}: #{ex.message}")
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            end
          elsif (bind[:command].is_a?(Regexp))
            if (text =~ bind[:command])
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    bind[:object].public_send(bind[:method], nick, text)
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  # TODO: move this to an addon handler
                  nick.message("#{self.class} error: #{ex.class}: #{ex.message}")
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            end
          else
            LOGGER.error("#{self.class}: unsure how to handle bind #{bind.inspect}, it isn't a string or regexp.")
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end