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
        @channel_list = @server_interface.channel_list
      end

      def handle_who_list_entry(nick_name, uhost, channel_name, mode)
        if (nick_name == @bot.real_nick && @server_interface.myself.uhost.empty?)
          @server_interface.myself = IRCTypes::Nick.from_uhost(@server_interface, uhost)
        end

        channel = @channel_list.get(channel_name)
        nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)

        if (mode.include?('@'))
          nick.opped = true
        elsif (mode.include?('+'))
          nick.voiced = true
        end
        channel.nick_list.add(nick)
      end

      def handle_who_list_end(channel_name)
        channel = @channel_list.get(channel_name)
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
        @channel_list.clear
      end

      def handle_quit(nick, reason)
        if (reason.nil? || reason.empty?)
          LOGGER.debug("#{nick.name} quit IRC")
        else
          LOGGER.debug("#{nick.name} quit IRC (#{reason})")
        end
        @bot.bind_handler.dispatch_quit_binds(nick, reason)
        @channel_list.all_channels do |channel|
          if (!channel.synced?)
            LOGGER.debug("rejected quit on #{channel.name} because it is not synced yet.")
            return
          end
          channel.delete_silent(nick)
        end
      end

      def dispatch_part(uhost, channel_name, reason)
        channel = @channel_list.get(channel_name)
        nick_name = uhost.split('!').first
        if (nick_name == @bot.real_nick)
          handle_self_part(channel_namee, reason)
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
        @channel_list.delete(channel)
      end

      def dispatch_join(uhost, channel_name)
        nick_name = uhost.split('!').first
        if (nick_name == @bot.real_nick)
          if (nick_name == @bot.real_nick && @server_interface.myself.uhost.empty?)
            @server_interface.myself = IRCTypes::Nick.from_uhost(@server_interface, uhost)
          end
          handle_self_join(channel_name)
        else
          channel = @channel_list.get(channel_name)
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
        channel = @channel_list.create(channel_name)
        channel.sync_begin
      end

      def dispatch_mode(uhost, channel_name, mode)
        channel = @channel_list.get(channel_name)
        if (uhost == @bot.server.real_address)
          handle_server_mode(channel, mode)
        else
          if (uhost == @server_interface.myself.uhost)
            nick = @server_interface.myself
          else
            nick_name = uhost.split('!').first
            nick = channel.nick_list.get(nick_name)
          end
          channel = @channel_list.get(channel_name)
          handle_mode(nick, channel, mode)
        end
      end

      def handle_server_mode(channel, mode)
        LOGGER.debug("server sets #{channel.name} mode: #{mode}")
      end

      def handle_mode(nick, channel, raw_mode_string)
        mode = IRCTypes::Mode.new
        mode_string = raw_mode_string.strip
        mode.parse_string(mode_string)

        if (mode.ops.any?)
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

        if (mode.deops.any?)
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

        if (mode.voices.any?)
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

        if (mode.devoices.any?)
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
          when /^\?about$/i, /^\?help$/i
            send_help(channel)
          when /^\?reload$/i
            reload_addons(channel, nick)
          else
            LOGGER.debug("#{channel.name} <#{nick.name}> #{text}")
            @bot.bind_handler.dispatch_channel_binds(channel, nick, text)
        end
      end

      def send_help(channel)
        channel.message("#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        if (@bot.addons.count > 0)
          @bot.addons.each do |addon|
            channel_listeners = addon[:object].listeners.select{|listener| listener[:type] == :channel && listener[:command].is_a?(String)}
            listener_string = ""
            if (channel_listeners.count > 0)
              commands = channel_listeners.collect{|foo| foo[:command]}
              listener_string = " (" + commands.join(', ') + ")"
            end
            channel.message(" + #{addon[:name]} version #{addon[:version]} by #{addon[:author]}#{listener_string}")
          end
        end
      end

      def reload_addons(channel, nick)
        user_model = Models::User.get_from_nick_object(nick)
        if (user_model.nil? || !user_model.manager?)
          LOGGER.warn("#{nick.uhost} tried to reload addons!")
          channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        elsif (@bot.addons.count == 0)
          channel.message("#{nick.name}: No addons loaded...")
          return
        end

        LOGGER.info("#{nick.uhost} reloaded addons.")
        channel.message("unloading addons: #{@bot.addons.collect{|addon| addon[:name]}.join(', ')}")
        @bot.unload_addons
        @bot.load_addons
        channel.message("loaded addons: #{@bot.addons.collect{|addon| addon[:name]}.join(', ')}")
      rescue Exception => ex
        LOGGER.error("addon reload error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_channel_notice(channel, nick, text)
        LOGGER.debug("#{channel.name} NOTICE <#{nick.name}> #{text}")
      end
    end
  end
end
