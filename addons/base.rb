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
        on_channel   'topic',   :change_topic
        on_channel_emote        :channel_emote
        on_topic                :handle_topic_change
      end

      def channel_emote(channel, nick, emote)
        if (emote.split(/\s+/).collect { |words| words.downcase }.include?(@bot.real_nick))
          wait_a_sec
          channel.emote('ducks')
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
        channel.message("#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        if (@bot.addons.count > 0)
          @bot.addons.each do |addon|
            if (addon[:name] == 'base')
              next
            end
            channel_binds = addon[:object].binds.select { |bind| bind[:type] == :channel && bind[:command].is_a?(String) }
            bind_string = ''
            if (channel_binds.count > 0)
              commands = channel_binds.collect { |bind| @bot.channel_command_character + bind[:command] }
              bind_string = ' (' + commands.sort.join(', ') + ')'
            end
            channel.message(" + #{addon[:name]} version #{addon[:version]} by #{addon[:author]}#{bind_string}")
          end
        end
      end

      def reload_addons(channel, nick, command)
        user = user_list.get_from_nick_object(nick)
        if (user.nil? || !user.role.director?)
          return
        end

        if (@bot.addons.count == 0)
          channel.message('no addons loaded.')
        else
          LOGGER.info("#{user.pretty_name} reloaded addons.")
          addon_list = @bot.addons.select { |addon| addon[:name] != 'base' }
          addon_names = addon_list.collect { |addon| addon[:name] }
          channel.message("unloading addons: #{addon_names.join(', ')}")
          @bot.git_pull
          @bot.reload_addons
          addon_list = @bot.addons.select { |addon| addon[:name] != 'base' }
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
