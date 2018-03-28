require 'axial/constants'
require 'axial/handlers/patterns'
require 'axial/colors'
require 'axial/irc_types/channel'
require 'axial/irc_types/mode'

class ChannelHandlerException < StandardError
end

module Axial
  module Handlers
    class ChannelHandler
      def initialize(bot)
        @bot = bot
        @server_interface = @bot.server_interface
      end

      def handle_who_list_entry(nick_name, uhost, channel_name, mode)
        if (nick_name == @bot.real_nick && @server_interface.myself.uhost.empty?)
          @server_interface.myself = IRCTypes::Nick.from_uhost(@server_interface, uhost)
        end

        channel = @server_interface.channel_list.get(channel_name)
        nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)

        if (mode.include?('@'))
          if (nick == @server_interface.myself)
            channel.opped = true
          else
            nick.opped = true
            channel.nick_list.add(nick)
          end
        elsif (mode.include?('+'))
          if (nick == @server_interface.myself)
            channel.voiced = true
          else
            nick.voiced = true
            channel.nick_list.add(nick)
          end
        else
          channel.nick_list.add(nick)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_ban_list_entry(channel, mask, who_set, set_at)
        puts "ban: #{channel} | #{mask} | #{who_set} | #{set_at}"
#        channel = @server_interface.channel_list.get(channel_name)
#        channel.irc_ban_list_monitor.synchronize do
#          irc_ban_list = IRCTypes::BanList.new
#          channel.irc_ban_list.clear
#          channel.irc_ban_list.add
#        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_ban_list_end(channel_name)
        channel = @server_interface.channel_list.get(channel_name)
        @bot.bind_handler.dispatch_irc_ban_list_end_binds(channel)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_who_list_end(channel_name)
        channel = @server_interface.channel_list.get(channel_name)
        channel.sync_complete
        @bot.bind_handler.dispatch_channel_sync_binds(channel)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_quit(uhost, reason)
        nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)
        if (reason.nil?)
          reason = ''
        else
          reason = reason.strip
        end

        if (nick == @server_interface.myself)
          handle_self_quit(reason)
        else
          handle_quit(nick, reason)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_self_quit(reason)
        if (reason.empty?)
          LOGGER.debug("I quit IRC.")
        else
          LOGGER.debug("I quit IRC. (#{reason})")
        end
        @server_interface.channel_list.clear
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_quit(nick, reason)
        if (reason.empty?)
          LOGGER.debug("#{nick.name} quit IRC")
        else
          LOGGER.debug("#{nick.name} quit IRC (#{reason})")
        end

        @server_interface.channel_list.all_channels.each do |channel|
          if (!channel.synced?)
            LOGGER.debug("rejected quit on #{channel.name} because it is not synced yet.")
          else
            channel.nick_list.delete_silent(nick)
          end
        end

        @bot.bind_handler.dispatch_quit_binds(nick, reason)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_kick(uhost, channel_name, kicked_nick_name, reason)
        nick_name = uhost.split('!').first
        channel = @server_interface.channel_list.get(channel_name)
        kicker_nick = channel.nick_list.get(nick_name)
        kicked_nick = channel.nick_list.get(kicked_nick_name)

        if (kicked_nick == @server_interface.myself)
          handle_self_kick(channel, kicker_nick, reason)
        else
          if (uhost == @server_interface.myself.uhost)
            handle_kick(channel, @server_interface.myself, kicked_nick, reason)
          else
            handle_kick(channel, kicker_nick, kicked_nick, reason)
          end
        end
      end

      def handle_self_kick(channel, kicker_nick, reason)
        LOGGER.warn("kicked from #{channel.name} by #{kicker_nick.name}: #{reason}")
        @server_interface.channel_list.clear
        @bot.bind_handler.dispatch_self_kick_binds(channel, kicker_nick, reason)
      end

      def handle_kick(channel, kicker_nick, kicked_nick, reason)
        LOGGER.debug("#{kicker_nick.name} kicked #{kicked_nick.name} from #{channel.name}: #{reason}")
        channel.nick_list.delete(kicked_nick)
        @bot.bind_handler.dispatch_kick_binds(channel, kicker_nick, kicked_nick, reason)
      end

      def dispatch_part(uhost, channel_name, reason)
        channel = @server_interface.channel_list.get(channel_name)
        nick_name = uhost.split('!').first

        if (reason.nil?)
          reason = ''
        else
          reason = reason.strip
        end

        if (uhost == @server_interface.myself.uhost)
          handle_self_part(channel_name, reason)
        else
          nick = channel.nick_list.get(nick_name)
          handle_part(channel, nick, reason)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_part(channel, nick, reason)
        if (!channel.synced?)
          LOGGER.debug("rejected channel join because #{channel.name} is not synced yet.")
          return
        end
        if (reason.empty?)
          LOGGER.debug("#{nick.name} left #{channel.name}")
        else
          LOGGER.debug("#{nick.name} left #{channel.name} (#{reason})")
        end
        channel.nick_list.delete(nick)
        @bot.bind_handler.dispatch_part_binds(channel, nick, reason)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_self_part(channel, reason)
        if (reason.empty?)
          LOGGER.debug("I left #{channel.name}")
        else
          LOGGER.debug("I left #{channel.name} (#{reason})")
        end
        @server_interface.channel_list.delete(channel)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_join(uhost, channel_name)
        nick_name = uhost.split('!').first
        if (@server_interface.myself.uhost.empty?)
          if (nick_name == @bot.real_nick)
            @server_interface.myself = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          end
        end

        if (uhost == @server_interface.myself.uhost)
          handle_self_join(channel_name)
        else
          channel = @server_interface.channel_list.get(channel_name)
          nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          handle_join(channel, nick)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_join(channel, nick)
        if (!channel.synced?)
          LOGGER.debug("rejected channel join because #{channel.name} is not synced yet.")
          return
        end
        LOGGER.debug("#{nick.name} joined #{channel.name}")
        @bot.bind_handler.dispatch_join_binds(channel, nick)
        channel.nick_list.add(nick)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_self_join(channel_name)
        LOGGER.info("joined channel #{channel_name}")
        channel = @server_interface.channel_list.create(channel_name)
        channel.sync_begin
        @bot.bind_handler.dispatch_self_join_binds(channel)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_mode(uhost, channel_name, mode)
        channel = @server_interface.channel_list.get(channel_name)
        if (uhost == @bot.server.real_address)
          handle_server_mode(channel, mode)
        else
          if (uhost == @server_interface.myself.uhost)
            nick = @server_interface.myself
          else
            nick_name = uhost.split('!').first
            nick = channel.nick_list.get(nick_name)
          end
          channel = @server_interface.channel_list.get(channel_name)
          handle_mode(nick, channel, mode)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_server_mode(channel, mode)
        LOGGER.debug("server sets #{channel.name} mode: #{mode}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_nick_change(uhost, new_nick_name)
        if (uhost == @server_interface.myself.uhost)
          handle_self_nick(new_nick_name)
        else
          old_nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          handle_nick_change(old_nick, new_nick_name)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_self_nick(new_nick)
        LOGGER.debug("I changed nicks: #{new_nick}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_nick_change(old_nick, new_nick_name)
        new_nick = nil
        @server_interface.channel_list.all_channels.each do |channel|
          if (!channel.synced?)
            LOGGER.debug("rejected nick change on #{channel.name} because it is not synced yet.")
            return
          end
          if (channel.nick_list.include?(old_nick))
            if (new_nick.nil?)
              new_nick = channel.nick_list.rename(old_nick, new_nick_name)
            else
              channel.nick_list.rename(old_nick, new_nick_name)
            end
          end
        end
        LOGGER.debug("#{old_nick.name} changed nick to #{new_nick.name}")
        @bot.bind_handler.dispatch_nick_change_binds(old_nick, new_nick)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_mode(nick, channel, raw_mode_string)
        mode = IRCTypes::Mode.new
        mode_string = raw_mode_string.strip
        mode.parse_string(mode_string)

        if (mode.ops.any? && channel.synced?)
          mode.ops.each do |nick_name|
            if (nick_name == @server_interface.myself.name)
              channel.opped = true
            else
              if (channel.synced?)
                subject_nick = channel.nick_list.get(nick_name)
                subject_nick.opped = true
              end
            end
          end
        end

        if (mode.deops.any? && channel.synced?)
          mode.deops.each do |nick_name|
            if (nick_name == @server_interface.myself.name)
              channel.opped = false
            else
              if (channel.synced?)
                subject_nick = channel.nick_list.get(nick_name)
                subject_nick.opped = false
              end
            end
          end
        end

        if (mode.voices.any? && channel.synced?)
          mode.voices.each do |nick_name|
            if (nick_name == @server_interface.myself.name)
              channel.voiced = true
            else
              if (channel.synced?)
                subject_nick = channel.nick_list.get(nick_name)
                subject_nick.voiced = true
              end
            end
          end
        end

        if (mode.devoices.any? && channel.synced?)
          mode.devoices.each do |nick_name|
            if (nick_name == @server_interface.myself.name)
              channel.voiced = false
            else
              if (channel.synced?)
               subject_nick = channel.nick_list.get(nick_name)
               subject_nick.voiced = false
              end
            end
          end
        end

        @bot.bind_handler.dispatch_mode_binds(channel, nick, mode)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_channel_action(channel, nick, unstripped_text)
        text = unstripped_text.strip
        LOGGER.debug("ACTION #{channel.name}: * #{nick.name} #{text}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_channel_message(channel, nick, unstripped_text)
        if (!channel.synced?)
          LOGGER.debug("rejected channel message because #{channel.name} is not synced yet.")
          return
        end
        text = unstripped_text.strip

        ignore_list = [ 'howto', 'lockie']
        if (ignore_list.include?(nick.name.downcase))
          return
        end

        if (text.empty?)
          return
        end

        case text
          when /^\x01ACTION/i
            handle_channel_action(channel, nick, text)
          else
            LOGGER.debug("#{channel.name} <#{nick.name}> #{text}")
            @bot.bind_handler.dispatch_channel_binds(channel, nick, text)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_channel_notice(channel, nick, text)
        LOGGER.debug("#{channel.name} NOTICE <#{nick.name}> #{text}")
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
