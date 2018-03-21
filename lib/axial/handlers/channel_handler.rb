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
        end
      end

      def handle_who_list_end(channel_name)
        channel = @server_interface.channel_list.get(channel_name)
        channel.sync_complete
        @bot.bind_handler.dispatch_channel_sync_binds(channel)
      end

      def dispatch_quit(uhost, reason)
        nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)
        if (nick.name == @bot.real_nick)
          handle_self_quit(reason)
        else
          handle_quit(nick, reason)
        end
      end

      def handle_self_quit(reason)
        if (reason.nil? || reason.empty?)
          LOGGER.debug("I quit IRC.")
        else
          LOGGER.debug("I quit IRC. (#{reason})")
        end
        @server_interface.channel_list.clear
      end

      def handle_quit(nick, reason)
        if (reason.nil? || reason.empty?)
          LOGGER.debug("#{nick.name} quit IRC")
        else
          LOGGER.debug("#{nick.name} quit IRC (#{reason})")
        end
        @bot.bind_handler.dispatch_quit_binds(nick, reason)
        @server_interface.channel_list.all_channels.each do |channel|
          if (!channel.synced?)
            LOGGER.debug("rejected quit on #{channel.name} because it is not synced yet.")
            return
          end
          channel.nick_list.delete_silent(nick)
        end
      end

      def dispatch_part(uhost, channel_name, reason)
        channel = @server_interface.channel_list.get(channel_name)
        nick_name = uhost.split('!').first
        if (nick_name == @bot.real_nick)
          handle_self_part(channel_name, reason)
        else
          nick = channel.nick_list.get(nick_name)
          handle_part(channel, nick, reason)
        end
      end

      def handle_part(channel, nick, reason)
        if (!channel.synced?)
          LOGGER.debug("rejected channel join because #{channel.name} is not synced yet.")
          return
        end
        if (reason.nil? || reason.empty?)
          LOGGER.debug("#{nick.name} left #{channel.name}")
        else
          LOGGER.debug("#{nick.name} left #{channel.name} (#{reason})")
        end
        @bot.bind_handler.dispatch_part_binds(channel, nick, reason)
        channel.nick_list.delete(nick)
      end

      def handle_self_part(channel, reason)
        if (reason.nil? || reason.empty?)
          LOGGER.debug("I left #{channel.name}")
        else
          LOGGER.debug("I left #{channel.name} (#{reason})")
        end
        @server_interface.channel_list.delete(channel)
      end

      def dispatch_join(uhost, channel_name)
        nick_name = uhost.split('!').first
        if (nick_name == @bot.real_nick)
          if (nick_name == @bot.real_nick && @server_interface.myself.uhost.empty?)
            @server_interface.myself = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          end
          handle_self_join(channel_name)
        else
          channel = @server_interface.channel_list.get(channel_name)
          nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          handle_join(channel, nick)
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
      end

      def handle_self_join(channel_name)
        LOGGER.info("joined channel #{channel_name}")
        channel = @server_interface.channel_list.create(channel_name)
        channel.sync_begin
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
      end

      def handle_server_mode(channel, mode)
        LOGGER.debug("server sets #{channel.name} mode: #{mode}")
      end

      def dispatch_nick_change(uhost, new_nick_name)
        if (uhost == @server_interface.myself.uhost)
          handle_self_nick(new_nick_name)
        else
          old_nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          handle_nick_change(old_nick, new_nick_name)
        end
      end

      def handle_self_nick(new_nick)
        LOGGER.debug("I changed nicks: #{new_nick}")
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
              puts new_nick.name
            else
              channel.nick_list.rename(old_nick, new_nick_name)
            end
          end
        end
        LOGGER.debug("#{old_nick.name} changed nick to #{new_nick.name}")
        @bot.bind_handler.dispatch_nick_change_binds(old_nick, new_nick)
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
      end

      def handle_channel_action(channel, nick, unstripped_text)
        text = unstripped_text.strip
        LOGGER.debug("ACTION #{channel.name}: * #{nick.name} #{text}")
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
      end

      def handle_channel_notice(channel, nick, text)
        LOGGER.debug("#{channel.name} NOTICE <#{nick.name}> #{text}")
      end
    end
  end
end
