require 'axial/addon'
require 'axial/api/geo_names/search_json'
require 'axial/api/wunderground/q'

module Axial
  module Addons
    class Base < Axial::Addon

      def initialize(bot)
        super

        @name    = 'base'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?help',   :send_help
        on_channel '?about',  :send_help
        on_channel '?reload', :reload_addons
      end

      def send_help(channel, nick, command)
        channel.message("#{Constants::AXIAL_NAME} version #{Constants::AXIAL_VERSION} by #{Constants::AXIAL_AUTHOR} (ruby version #{RUBY_VERSION}p#{RUBY_PATCHLEVEL})")
        if (@bot.addons.count > 0)
          @bot.addons.each do |addon|
            if (addon[:name] == 'base')
              next
            end
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

      def reload_addons(channel, nick, command)
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
    end
  end
end
