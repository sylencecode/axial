require 'axial/addon'

module Axial
  module Addons
    class Base < Axial::Addon
      def initialize(bot)
        super

        @name                   = 'base'
        @author                 = 'sylence <sylence@sylence.org>'
        @version                = '1.1.0'

        throttle                10

        on_channel    'help',   :send_help
        on_channel   'about',   :send_help
        on_channel  'reload',   :reload_addons
        on_channel_emote        :channel_emote
        on_topic                :handle_topic_change
      end

      def channel_emote(channel, nick, emote)
        if (emote.split(/\s+/).collect { |words| words.downcase }.include?(@bot.real_nick))
          timer.in_a_tiny_bit do
            channel.emote('ducks')
          end
        end
      end

      def change_topic(channel, nick, command)
        if (command.args.empty?)
          channel.message("#{nick.name}: current topic for #{channel.name} is: #{channel.topic}")
        else
          new_topic = command.args
          if (channel.opped?)
            channel.set_topic(new_topic)
          end
        end
      end

      def handle_topic_change(channel, nick, topic)
        LOGGER.debug("new topic from #{nick.name}: #{topic}")
      end

      def ctcp_ping_user(channel, nick, command)
        server.send_ctcp(nick, 'PING', Time.now.to_i.to_s)
      end

      def send_help(channel, nick, command)
        exclude_addons = [ 'axnet master', 'axnet slave', 'base' ]
        channel.message("                    #{Colors.cyan}#{Constants::AXIAL_NAME}#{Colors.reset} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        channel.message(' ')
        if (@bot.addons.any?)
          addon_name_length = @bot.addons.collect { |tmp_addon| tmp_addon[:name].length }.max
          all_string_commands = @bot.addons.collect { |tmp_addon| tmp_addon[:object].binds.collect { |tmp_bind| (tmp_bind[:type] == :channel && tmp_bind[:command].is_a?(String)) ? tmp_bind[:command] : nil } }.flatten
          all_string_commands.delete_if { |command| command.nil? }
          max_command_length = all_string_commands.collect{ |tmp_command| tmp_command.length }.max + 2
          @bot.addons.each do |addon|
            if (exclude_addons.include?(addon[:name].downcase))
              next
            end

            binds = addon[:object].binds.select { |bind| bind[:type] == :channel && bind[:command].is_a?(String) }
            commands = binds.collect { |bind| bind[:command] }.sort_by { |command| command.gsub(/^\+/, '').gsub(/^-/, '') }.collect { |command| @bot.channel_command_character + command }
            command_chunks = []
            while (commands.count >= 6)
              chunk = []
              6.times do
                tmp_command = commands.shift.ljust(max_command_length)
                chunk.push(tmp_command)
              end
              command_chunks.push(chunk)
            end

            if (commands.any?)
              command_chunks.push(commands.collect { |tmp_command| tmp_command.ljust(max_command_length) })
            end

            command_chunks.each_with_index do |chunk, i|
              if (i.zero?)
                channel.message("#{Colors.blue}#{addon[:name].rjust(addon_name_length)}#{Colors.reset} #{Colors.gray}|#{Colors.reset} #{chunk.join("#{Colors.gray} | #{Colors.reset}")}")
              else
                channel.message("#{' '.ljust(addon_name_length)} #{Colors.gray}|#{Colors.reset} #{chunk.join("#{Colors.gray} | #{Colors.reset}")}")
              end
            end
          end
        else
          channel.message('no addons loaded.')
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def reload_addons(channel, nick, command)
        user = user_list.get_from_nick_object(nick)
        if (user.nil? || !user.role.director?)
          return
        end

        if (@bot.addons.empty?)
          channel.message('no addons loaded.')
        else
          LOGGER.info("#{user.pretty_name} reloaded addons.")
          addon_list = @bot.addons.reject { |addon| addon[:name] == 'base' }
          addon_names = addon_list.collect { |addon| addon[:name] }
          channel.message("unloading addons: #{addon_names.join(', ')}")
          @bot.git_pull
          @bot.reload_addons
          addon_list = @bot.addons.reject { |addon| addon[:name] == 'base' }
          addon_names = addon_list.collect { |addon| addon[:name] }
          channel.message("loaded addons: #{addon_names.join(', ')}")
        end
      rescue Exception => ex
        channel.message("addon reload error: #{ex.class}: #{ex.message}")
        LOGGER.error("addon reload error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
