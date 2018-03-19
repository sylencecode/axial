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
      end

      # start from NAMES nick list
      # update the list with data from the WHO
      # run a select on the nick list for any nicks not in the channel any longer
      # make the nick list a hash of nick string to nick objects?

      def handle_who_list_entry(nick, uhost, channel_name, mode)
        LOGGER.debug("|#{nick}|#{uhost}|#{channel_name}|#{mode}|")
        # start populating this shit
        if (mode.include?('@'))
          LOGGER.debug "#{nick} is an op"
        elsif (mode.include?('+'))
          LOGGER.debug "#{nick} is a voice"
        end
      end

      def handle_who_list_end(channel_name)
        if (@bot.server.channel_list.has_key?(channel_name.downcase))
          channel = @bot.server.channel_list[channel_name.downcase]
          # unlock whatever else was waiting?
        else
          raise(ChannelHandlerException, "No channel list entry found for #{channel_name}")
        end
        LOGGER.debug("done with #{channel.name}")
      end

      def dispatch_part(captures)
        uhost, channel_name, reason = captures
        nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)
        if (@bot.server.channel_list.has_key?(channel_name.downcase))
          channel = @bot.server.channel_list[channel_name.downcase]
        else
          raise(ChannelHandlerException, "No channel list entry found for #{channel_name}")
        end

        if (nick.name == @bot.real_nick)
          handle_self_part(channel, reason)
        else
          handle_part(channel, nick, reason)
        end
      end

      def dispatch_quit(captures)
        uhost, reason = captures
        puts captures.inspect
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
      end

      def handle_quit(nick, reason)
        # TODO: if on any channel, remove them from the channel list
        if (reason.nil? || reason.empty?)
          LOGGER.debug("#{nick.name} quit IRC")
        else
          LOGGER.debug("#{nick.name} quit IRC (#{reason})")
        end
        @bot.bind_handler.dispatch_quit_binds(nick, reason)
      end

      def handle_part(channel, nick, reason)
        if (reason.nil? || reason.empty?)
          LOGGER.debug("#{nick.name} left #{channel.name}")
        else
          LOGGER.debug("#{nick.name} left #{channel.name} (#{reason})")
        end
        @bot.bind_handler.dispatch_part_binds(channel, nick, reason)
      end

      def handle_self_part(channel, reason)
        if (@bot.server.channel_list.has_key?(channel.name.downcase))
          @bot.server.channel_list.delete(channel.name.downcase)
        else
          raise(ChannelHandlerException, "No channel list entry found for #{channel.name}")
        end
        if (reason.nil? || reason.empty?)
          LOGGER.debug("I left #{channel.name}")
        else
          LOGGER.debug("I left #{channel.name} (#{reason})")
        end
      end

      def dispatch_join(captures)
        uhost, channel_name = captures
        nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)

        if (nick.name == @bot.real_nick)
          handle_self_join(channel_name)
        else
          if (@bot.server.channel_list.has_key?(channel_name.downcase))
            channel = @bot.server.channel_list[channel_name.downcase]
          else
            raise(ChannelHandlerException, "No channel list entry found for #{channel_name}")
          end
          handle_join(channel, nick)
        end
      end

      def handle_join(channel, nick)
        LOGGER.debug("#{nick.name} joined #{channel.name}")
        @bot.bind_handler.dispatch_join_binds(channel, nick)
      end

      def handle_self_join(channel_name)
        if (!@bot.server.channel_list.has_key?(channel_name.downcase))
          channel_object = IRCTypes::Channel.new(@bot.server_interface, channel_name)
          @bot.server.channel_list[channel_name.downcase] = channel_object
          @bot.server_interface.send_who(channel_name)
        else
          raise(ChannelHandlerException, "I should not already have a channel object for #{channel_name}")
        end
        LOGGER.debug("I joined #{channel_name}")
      end

      def dispatch_mode(captures)
        uhost, channel_name, mode = captures
        if (@bot.server.channel_list.has_key?(channel_name.downcase))
          channel = @bot.server.channel_list[channel_name.downcase]
        else
          raise(ChannelHandlerException, "No channel list entry found for #{channel_name}")
        end
        if (uhost == @bot.server.address)
          handle_server_mode(channel, mode)
        else
          nick = IRCTypes::Nick.from_uhost(@bot.server_interface, uhost)
          handle_mode(nick, channel, mode)
        end
      end

      def handle_channel_action(channel, nick, unstripped_text)
        text = unstripped_text.strip
        LOGGER.debug("ACTION #{channel.name}: * #{nick.name} #{text}")
      end

      def handle_channel_message(channel, nick, unstripped_text)
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

      def handle_server_mode(channel, mode)
        LOGGER.debug("server sets #{channel.name} mode: #{mode}")
      end

      def handle_mode(nick, channel, raw_mode_string)
        mode_string = raw_mode_string.strip
        if (nick.name == @bot.real_nick)
          LOGGER.debug("I set #{channel.name} mode: #{raw_mode_string}")
        else
          mode = IRCTypes::Mode.new
          mode.parse_string(mode_string)
          @bot.bind_handler.dispatch_mode_binds(channel, nick, mode)
          LOGGER.debug("#{nick.name} sets #{channel.name} mode: #{mode_string.inspect}")
        end
      rescue Exception => ex
        LOGGER.error("addon reload error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
