require 'axial/addon'

module Axial
  module Addons
    class Base < Axial::Addon

      def initialize(bot)
        super

        @name    = 'base'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        on_channel   '?help',   :send_help
        on_channel  '?about',   :send_help
        on_channel '?reload',   :handle_channel_reload
        on_dcc      'reload',   :handle_dcc_reload
      end

      def handle_dcc_reload(dcc, command)
        reload_addons(dcc, dcc.user, command)
      end

      def handle_channel_reload(channel, nick, command)
        user = @bot.user_list.get_from_nick_object(nick)
        if (user.nil? || !user.director?)
          channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
        else
          reload_addons(channel, user, command)
        end
      end

      def send_help(channel, nick, command)
        channel.message("#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        if (@bot.addons.count > 0)
          @bot.addons.each do |addon|
            if (addon[:name] == 'base')
              next
            end
            channel_listeners = addon[:object].listeners.select{ |listener| listener[:type] == :channel && listener[:command].is_a?(String) }
            listener_string = ""
            if (channel_listeners.count > 0)
              commands = channel_listeners.collect{ |bind| bind[:command] }
              listener_string = " (" + commands.join(', ') + ")"
            end
            channel.message(" + #{addon[:name]} version #{addon[:version]} by #{addon[:author]}#{listener_string}")
          end
        end
      end

      def reload_addons(sender, user, command)
        if (@bot.addons.count == 0)
          sender.message("no addons loaded.")
        else
          LOGGER.info("#{user.pretty_name} reloaded addons.")
          addon_list = @bot.addons.select{ |addon| addon[:name] != 'base' }
          addon_names = addon_list.collect{ |addon| addon[:name] }
          sender.message("unloading addons: #{addon_names.join(', ')}")
          @bot.git_pull
          @bot.reload_addons
          addon_list = @bot.addons.select{ |addon| addon[:name] != 'base' }
          addon_names = addon_list.collect{ |addon| addon[:name] }
          sender.message("loaded addons: #{addon_names.join(', ')}")
        end
      rescue Exception => ex
        sender.message("addon reload error: #{ex.class}: #{ex.message}")
        LOGGER.error("addon reload error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
