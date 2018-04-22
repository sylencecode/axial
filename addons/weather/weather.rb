require 'axial/addon'
require 'axial/api/geo_names/search_json'
require 'axial/api/wunderground/q'

module Axial
  module Addons
    class Weather < Axial::Addon
      def initialize(bot)
        super

        @name                     = 'weather underground'
        @author                   = 'sylence <sylence@sylence.org>'
        @version                  = '1.1.0'

        throttle                  3

        on_channel  'weather|w',  :handle_weather
      end

      def weather_color(temp)
        if (temp >= 90)
          temp_color = Colors.red
        elsif (temp >= 70)
          temp_color = Colors.yellow
        elsif (temp <= 40)
          temp_color = Colors.blue
        elsif (temp <= 60)
          temp_color = Colors.cyan
        end
        return temp_color
      end

      def zip_or_geonames(query)
        location = nil
        if (query =~ /^[0-9][0-9][0-9][0-9][0-9]$/)
          location = query
        else
          geonames_location = API::GeoNames::SearchJSON.search(query)
          if (geonames_location.found?)
            location = geonames_location.to_wunderground
          end
        end

        return location
      end

      def handle_weather(channel, nick, command)
        query = command.args.strip
        if (query.empty?)
          channel.message("#{nick.name}: provide a zip code (US) or any location name.")
          return
        end

        query = (query.length <= 64) ? query : query[0..63]

        location = zip_or_geonames(query)
        if (location.nil?)
          channel.message("#{nick.name}: could not find a location named '#{query}'.")
          return
        end

        conditions = API::WUnderground::Q.get_current_conditions(location)
        send_conditions_to_channel(channel, nick, conditions)
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def send_conditions_to_channel(channel, nick, conditions) # rubocop:disable Metrics/AbcSize
        if (!conditions.found?)
          channel.message("#{nick.name}: no weather data found for '#{query}'.")
          return
        end

        msg = Color.cyan_prefix('weather', conditions.location)
        msg += conditions.weather.downcase + Color.gray(' |')
        msg += "#{weather_color(conditions.temp_f)} #{conditions.temp_f}f" + Color.gray(' | ')
        msg += "feels like:#{weather_color(conditions.feels_like_f)} #{conditions.feels_like_f}f" + Color.gray(' | ')
        msg += "humidity: #{conditions.relative_humidity}%" + Color.gray(' | ')
        msg += "visibility: #{conditions.visibility_mi}mi" + Color.gray(' | ')
        if (conditions.wind_mph.positive?)
          msg += "winds: #{conditions.wind_mph}mph from #{conditions.wind_dir.downcase}"
          if (conditions.wind_gust_mph.positive?)
            msg += " (gusts up to #{conditions.wind_gust_mph}mph)"
          end
        else
          msg += 'winds: calm'
        end

        channel.message(msg)
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}", __FILE__, __LINE__)
        end
      end
    end
  end
end
