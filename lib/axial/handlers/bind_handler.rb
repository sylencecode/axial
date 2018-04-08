require 'axial/irc_types/command'
require 'axial/irc_types/dcc'

module Axial
  module Handlers
    class BindHandler

      def initialize(bot)
        @bot = bot
        @binds = @bot.binds
      end

      def dispatch_axnet_connect_binds(handler)
        @binds.select{ |bind| bind[:type] == :axnet_connect }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], handler, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], handler)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_axnet_disconnect_binds(handler)
        @binds.select{ |bind| bind[:type] == :axnet_disconnect }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], handler, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], handler)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_banned_from_channel_binds(channel_name)
        @binds.select{ |bind| bind[:type] == :banned_from_channel }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel_name, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel_name)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_channel_full_binds(channel_name)
        @binds.select{ |bind| bind[:type] == :channel_full }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel_name, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel_name)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_channel_keyword_binds(channel_name)
        @binds.select{ |bind| bind[:type] == :channel_keyword }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel_name, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel_name)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_invited_to_channel_binds(nick, channel_name)
        @binds.select{ |bind| bind[:type] == :invited_to_channel }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel_name, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel_name)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_topic_change_binds(channel, nick, topic)
        @binds.select{ |bind| bind[:type] == :topic_change }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, nick, topic, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel, nick, topic)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_channel_invite_only_binds(channel_name)
        @binds.select{ |bind| bind[:type] == :channel_invite_only }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel_name, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel_name)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_mode_binds(channel, nick, mode)
        @binds.select{ |bind| bind[:type] == :mode }.each do |bind|
          Thread.new do
            begin
              if (bind[:modes].include?(:all) || (bind[:modes] & mode.channel_modes).any?)
                if (bind[:object].respond_to?(bind[:method]))
                  if (bind.has_key?(:args) && bind[:args].any?)
                    bind[:object].public_send(bind[:method], channel, nick, mode, *bind[:args])
                  else
                    bind[:object].public_send(bind[:method], channel, nick, mode)
                  end
                else
                  LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
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
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_quit_binds(nick, reason)
        @binds.select{ |bind| bind[:type] == :quit }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], nick, reason, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], nick, reason)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_self_kick_binds(channel, kicker_nick, reason)
        @binds.select{ |bind| bind[:type] == :self_kick }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, kicker_nick, reason, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel, kicker_nick, reason)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
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

      def dispatch_kick_binds(channel, kicker_nick, kicked_nick, reason)
        @binds.select{ |bind| bind[:type] == :kick }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, kicker_nick, kicked_nick, reason, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel, kicker_nick, kicked_nick, reason)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
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

      def dispatch_part_binds(channel, nick, reason)
        @binds.select{ |bind| bind[:type] == :part }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, nick, reason, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel, nick, reason)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_startup_binds()
        @binds.select{ |bind| bind[:type] == :startup }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], *bind[:args])
                else
                  bind[:object].public_send(bind[:method])
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_user_list_binds()
        @binds.select{ |bind| bind[:type] == :user_list }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], *bind[:args])
                else
                  bind[:object].public_send(bind[:method])
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_ban_list_binds()
        @binds.select{ |bind| bind[:type] == :ban_list }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], *bind[:args])
                else
                  bind[:object].public_send(bind[:method])
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_reload_binds()
        @binds.select{ |bind| bind[:type] == :reload }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], *bind[:args])
                else
                  bind[:object].public_send(bind[:method])
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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
        @binds.select{ |bind| bind[:type] == :nick_change }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], old_nick, new_nick, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], old_nick, new_nick)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_irc_ban_list_end_binds(channel)
        @binds.select{ |bind| bind[:type] == :irc_ban_list_end }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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
        @binds.select{ |bind| bind[:type] == :channel_sync }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_who_list_entry_binds(channel, nick)
        @binds.select{ |bind| bind[:type] == :who_list_entry }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, nick, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel, nick)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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
        @binds.select{ |bind| bind[:type] == :join }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, nick, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel, nick)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_self_join_binds(channel)
        @binds.select{ |bind| bind[:type] == :self_join }.each do |bind|
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
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

      def dispatch_axnet_binds(socket_handler, text)
        @binds.select{ |bind| bind[:type] == :axnet }.each do |bind|
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
              bind[:object].last = Time.now
              Thread.new do
                begin
                  if (bind.has_key?(:args) && bind[:args].any?)
                    bind[:object].public_send(bind[:method], socket_handler, command_object, *bind[:args])
                  else
                    bind[:object].public_send(bind[:method], socket_handler, command_object)
                  end
                rescue Exception => ex
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
              bind[:object].last = Time.now
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], socket_handler, command_object, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], socket_handler, command_object)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
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
              bind[:object].last = Time.now
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], socket_handler, command_object, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], socket_handler, command_object)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
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

      def dispatch_channel_binds(channel, nick, text)
        # TODO: break into smaller methods
        # any/all channel text
        @binds.select{ |bind| bind[:type] == :channel_any }.each do |bind|
          if (bind[:object].throttle_secs > 0)
            if ((Time.now - bind[:object].last) < bind[:object].throttle_secs)
              next
            end
          end
          Thread.new do
            begin
              if (bind[:object].respond_to?(bind[:method]))
                if (bind.has_key?(:args) && bind[:args].any?)
                  bind[:object].public_send(bind[:method], channel, nick, text, *bind[:args])
                else
                  bind[:object].public_send(bind[:method], channel, nick, text)
                end
              else
                LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
              end
            rescue Exception => ex
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end

        leftovers = true
        @binds.select{ |bind| bind[:type] == :channel }.each do |bind|
          if (bind[:object].throttle_secs > 0)
            if ((Time.now - bind[:object].last) < bind[:object].throttle_secs)
              next
            end
          end
          if (bind[:command].is_a?(String))
            match = '^(' + Regexp.escape(@bot.channel_command_character) + Regexp.escape(bind[:command]) + ')'
            base_match = match + '$'
            args_match = match + '\s+(.*)'
            # this is done to ensure that a command is typed in its entirety, even if it had no arguments
            args_regexp = Regexp.new(args_match, true)
            base_regexp = Regexp.new(base_match, true)
            if (text =~ args_regexp)
              leftovers = false
              command, args = Regexp.last_match.captures
              command_object = IRCTypes::Command.new(command, args)
              bind[:object].last = Time.now
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], channel, nick, command_object, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], channel, nick, command_object)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            elsif (text =~ base_regexp)
              leftovers = false
              command = Regexp.last_match[1]
              args = ""
              command_object = IRCTypes::Command.new(command, args)
              bind[:object].last = Time.now
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], channel, nick, command_object, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], channel, nick, command_object)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
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
              leftovers = false
              bind[:object].last = Time.now
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], channel, nick, text, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], channel, nick, text)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            end
          else
            LOGGER.error("#{self.class}: unsure how to handle bind #{bind[:text]} - it isn't a string or regexp.")
          end
        end

        if (leftovers)
          # wasn't a command, check against the channel leftover patterns
          @binds.select{ |bind| bind[:type] == :channel_leftover }.each do |bind|
            if (bind[:object].throttle_secs > 0)
              if ((Time.now - bind[:object].last) < bind[:object].throttle_secs)
                next
              end
            end
            if (bind[:text].is_a?(Regexp))
              if (text =~ bind[:text])
                bind[:object].last = Time.now
                Thread.new do
                  begin
                    if (bind[:object].respond_to?(bind[:method]))
                      if (bind.has_key?(:args) && bind[:args].any?)
                        bind[:object].public_send(bind[:method], channel, nick, text, *bind[:args])
                      else
                        bind[:object].public_send(bind[:method], channel, nick, text)
                      end
                    else
                      LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                    end
                  rescue Exception => ex
                    LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                    ex.backtrace.each do |i|
                      LOGGER.error(i)
                    end
                  end
                end
                break
              end
            else
              LOGGER.error("#{self.class}: unsure how to handle bind #{bind[:text]} - it isn't a regexp.")
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_privmsg_binds(nick, text)
        dispatched_commands = []
        @binds.select{ |bind| bind[:type] == :privmsg }.each do |bind|
          if (bind[:object].throttle_secs > 0)
            if ((Time.now - bind[:object].last) < bind[:object].throttle_secs)
              next
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
              dispatched_commands.push(bind)
              bind[:object].last = Time.now
              command, args = Regexp.last_match.captures
              command_object = IRCTypes::Command.new(command, args)
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], nick, command_object, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], nick, command_object)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            elsif (text =~ base_regexp)
              dispatched_commands.push(bind)
              bind[:object].last = Time.now
              command = Regexp.last_match[1]
              args = ""
              command_object = IRCTypes::Command.new(command, args)
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], nick, command_object, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], nick, command_object)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
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
              bind[:object].last = Time.now
              dispatched_commands.push(bind)
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], nick, text, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], nick, text)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
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
        return dispatched_commands
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_dcc_binds(dcc, text)
        dispatched_commands = []
        @binds.select{ |bind| bind[:type] == :dcc }.each do |bind|
          if (bind[:command].is_a?(String))
            match = '^(' + Regexp.escape(@bot.dcc_command_character) + Regexp.escape(bind[:command]) + ')'
            base_match = match + '$'
            args_match = match + '\s+(.*)'
            # this is done to ensure that a command is typed in its entirety, even if it had no arguments
            args_regexp = Regexp.new(args_match, true)
            base_regexp = Regexp.new(base_match, true)
            if (text =~ args_regexp)
              dispatched_commands.push(bind)
              command, args = Regexp.last_match.captures
              command_object = IRCTypes::Command.new(command, args)
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], dcc, command_object, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], dcc, command_object)
                    end
                  else
                    LOGGER.error("#{bind[:object].class} configured to call back #{bind[:method]} but does not respond to it publicly.")
                  end
                rescue Exception => ex
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            elsif (text =~ base_regexp)
              dispatched_commands.push(bind)
              command = Regexp.last_match[1]
              args = ""
              command_object = IRCTypes::Command.new(command, args)
              Thread.new do
                begin
                  if (bind[:object].respond_to?(bind[:method]))
                    if (bind.has_key?(:args) && bind[:args].any?)
                      bind[:object].public_send(bind[:method], dcc, command_object, *bind[:args])
                    else
                      bind[:object].public_send(bind[:method], dcc, command_object)
                    end
                  end
                rescue Exception => ex
                  LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                  ex.backtrace.each do |i|
                    LOGGER.error(i)
                  end
                end
              end
              break
            end
          else
            LOGGER.error("#{self.class}: unsure how to handle bind #{bind.command} to #{bind.method}, it isn't a string or regexp.")
          end
        end
        return dispatched_commands
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
