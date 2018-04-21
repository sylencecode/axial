require 'axial/constants'
require 'axial/handlers/patterns'
require 'axial/irc_types/channel'
require 'axial/irc_types/mode'
require 'axial/irc_types/channel_ban'

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
        if (nick_name.casecmp(@bot.real_nick).zero?)
          @server_interface.myself.uhost = uhost
        end

        channel = @server_interface.channel_list.get(channel_name)
        nick = @server_interface.channel_list.get_any_nick_from_uhost(uhost)
        if (nick.nil?)
          nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
        end

        if (mode.include?('@'))
          if (nick == @server_interface.myself)
            channel.opped = true
          else
            nick.set_opped(channel, true)
            channel.nick_list.add(nick)
          end
        elsif (mode.include?('+'))
          if (nick == @server_interface.myself)
            channel.voiced = true
          else
            nick.set_voiced(channel, true)
            channel.nick_list.add(nick)
          end
        else
          channel.nick_list.add(nick)
        end
        @bot.bind_handler.dispatch_who_list_entry_binds(channel, nick)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_ban_list_entry(channel_name, mask, set_by, set_at)
        channel = @server_interface.channel_list.get(channel_name)
        if (channel.ban_list.synced?)
          channel.ban_list.synced = false
          channel.ban_list.clear
        end
        ban = IRCTypes::ChannelBan.new(mask, set_by, set_at)
        channel.ban_list.add(ban)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_ban_list_end(channel_name)
        channel = @server_interface.channel_list.get(channel_name)
        channel.ban_list.synced = true
        @bot.bind_handler.dispatch_irc_ban_list_end_binds(channel)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_banned_from_channel(channel_name)
        @bot.bind_handler.dispatch_banned_from_channel_binds(channel_name)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_channel_invite_only(channel_name)
        @bot.bind_handler.dispatch_channel_invite_only_binds(channel_name)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_invited_to_channel(uhost, channel_name)
        nick = @server_interface.channel_list.get_any_nick_from_uhost(uhost)
        if (nick.nil?)
          nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
        end

        channel = @server_interface.channel_list.get_silent(channel_name)
        if (channel.nil?)
          @bot.bind_handler.dispatch_invited_to_channel_binds(nick, channel_name)
        end
      end

      def handle_channel_keyword(channel_name)
        @bot.bind_handler.dispatch_channel_keyword_binds(channel_name)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_channel_full(channel_name)
        @bot.bind_handler.dispatch_channel_full_binds(channel_name)
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
          LOGGER.debug('I quit IRC.')
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
        @server_interface.channel_list.delete(channel)
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

      def handle_self_part(channel_name, reason)
        channel = @server_interface.channel_list.get(channel_name)
        if (reason.empty?)
          LOGGER.debug("I left #{channel.name}")
        else
          LOGGER.debug("I left #{channel.name} (#{reason})")
        end
        @bot.bind_handler.dispatch_self_part_binds(channel)
        @server_interface.channel_list.delete(channel)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_join(uhost, channel_name)
        nick_name = uhost.split('!').first
        if (nick_name.casecmp(@bot.real_nick).zero?)
          @server_interface.myself.uhost = uhost
        end

        if (uhost == @server_interface.myself.uhost)
          handle_self_join(channel_name)
        else
          channel = @server_interface.channel_list.get(channel_name)
          nick = @server_interface.channel_list.get_any_nick_from_uhost(uhost)
          if (nick.nil?)
            nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          end
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
        @server_interface.trying_to_join.delete(channel_name.downcase)
        LOGGER.info("joined channel #{channel_name}")
        channel = @server_interface.channel_list.create(channel_name)
        channel.sync_begin
        @server_interface.set_channel_mode(channel_name, '')
        @server_interface.set_channel_mode(channel_name, '+b')
        @bot.bind_handler.dispatch_self_join_binds(channel)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def dispatch_mode(uhost, channel_name, mode_string)
        channel = @server_interface.channel_list.get(channel_name)
        if (uhost == @bot.server.real_address || !uhost.include?('!'))
          LOGGER.debug("server #{uhost} set #{channel_name} mode: #{mode_string}")
          fake_server_nick = IRCTypes::Nick.new(nil)
          fake_server_nick.name = "server"
          fake_server_nick.ident = "server"
          fake_server_nick.host = "#{uhost}"
          handle_mode(fake_server_nick, channel, mode_string)
        else
          if (uhost == @server_interface.myself.uhost)
            nick = @server_interface.myself
          else
            nick_name = uhost.split('!').first
            nick = channel.nick_list.get(nick_name)
          end
          handle_mode(nick, channel, mode_string)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_mode(nick, channel, raw_mode_string)
        channel.mode.merge_string(raw_mode_string)

        mode = IRCTypes::Mode.new(@server_interface.max_modes)
        mode_string = raw_mode_string.strip
        mode.parse_string(mode_string)

        if (mode.ops.any? && channel.synced?)
          mode.ops.each do |nick_name|
            if (nick_name == @server_interface.myself.name)
              if (channel.voiced?)
                channel.voiced = false
              end
              channel.opped = true
            else
              if (channel.synced?)
                subject_nick = channel.nick_list.get(nick_name)
                if (subject_nick.voiced_on?(channel))
                  subject_nick.set_voiced(channel, false)
                end
                subject_nick.set_opped(channel, true)
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
                subject_nick.set_opped(channel, false)
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
                subject_nick.set_voiced(channel, true)
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
                subject_nick.set_voiced(channel, false)
              end
            end
          end
        end

        if (mode.unbans.any?)
          if (channel.ban_list.synced?)
            mode.unbans.each do |mask|
              channel.ban_list.remove(mask)
            end
          else
            LOGGER.debug("rejected ban on #{channel.name} because it is not synced yet.")
          end
        end

        if (mode.bans.any?)
          if (channel.ban_list.synced?)
            mode.bans.each do |mask|
              ban = IRCTypes::ChannelBan.new(mask, nick.uhost, Time.now)
              channel.ban_list.add(ban)
            end
          else
            LOGGER.debug("rejected ban on #{channel.name} because it is not synced yet.")
          end
        end

        @bot.bind_handler.dispatch_mode_binds(channel, nick, mode)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_topic_change(uhost, channel_name, topic)
        channel = @server_interface.channel_list.get(channel_name)
        nick_name = uhost.split('!').first
        nick = channel.nick_list.get(nick_name)
        channel.topic = topic
        @bot.bind_handler.dispatch_topic_change_binds(channel, nick, topic)
        LOGGER.debug("#{channel.name} topic changed by #{nick.name} to: #{topic}")
      end

      def handle_initial_mode(channel_name, initial_mode)
        channel = @server_interface.channel_list.get(channel_name)
        mode_string = initial_mode.strip
        channel.mode.merge_string(mode_string)
      end

      def handle_initial_topic(channel_name, initial_topic)
        channel = @server_interface.channel_list.get(channel_name)
        channel.topic = initial_topic
      end

      def dispatch_created(channel_name, created_at)
        channel = @server_interface.channel_list.get(channel_name)
        channel.created = Time.at(created_at)
      end

      def dispatch_nick_change(uhost, new_nick_name)
        if (uhost == @server_interface.myself.uhost)
          handle_self_nick(new_nick_name)
        else
          handle_nick_change(uhost, new_nick_name)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_self_nick(new_nick)
        if (new_nick.casecmp(@bot.nick).zero?)
          @bot.connection_handler.nick_regained
        else
          LOGGER.debug("I changed nicks: #{new_nick}")
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_nick_change(uhost, new_nick_name)
        nick = @server_interface.channel_list.get_any_nick_from_uhost(uhost)
        if (!nick.nil?)
          old_nick_name = nick.name
        end

        if (nick.nil?)
          LOGGER.error("#{self.class} error: uhost '#{uhost}' changed nick to '#{new_nick_name}' but no previous record exists!")
        else
          @server_interface.channel_list.all_channels.each do |channel|
            if (!channel.synced?)
              LOGGER.debug("rejected nick change on #{channel.name} because it is not synced yet.")
            else
              if (channel.nick_list.include?(old_nick_name))
                channel.nick_list.rename(old_nick_name, new_nick_name)
              end
            end
          end

          nick.name = new_nick_name

          LOGGER.debug("#{old_nick_name} changed nick to #{new_nick_name}")
          @bot.bind_handler.dispatch_nick_change_binds(nick, old_nick_name)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_channel_emote(channel, nick, emote)
        emote = emote.gsub(/^\x01ACTION/, '').gsub(/\x01$/, '').strip
        LOGGER.debug("EMOTE #{channel.name}: * #{nick.name} #{emote.inspect}")
        @bot.bind_handler.dispatch_channel_emote_binds(channel, nick, emote)
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

        if (text.empty?)
          return
        end

        case text
          when /^\x01ACTION/i
            handle_channel_emote(channel, nick, text)
          when /\x01(\S+)(.*)\x01{0,1}/
            ctcp_command, ctcp_args = Regexp.last_match.captures
            ctcp_command.delete!("\u0001")
            ctcp_command.strip!
            ctcp_args.delete!("\u0001")
            ctcp_args.strip!
            @server_interface.handle_ctcp(nick, ctcp_command, ctcp_args)
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
