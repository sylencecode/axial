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

        throttle                  2

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

      def handle_weather(channel, nick, command)
        query = command.args.strip
        if (query.empty?)
          channel.message("#{nick.name}: provide a zip code (US) or any location name.")
          return
        end

        if (query.length > 63)
          query = query[0..63]
        end

        begin
          LOGGER.debug("weather request from #{nick.uhost} on #{channel.name}: #{query}")
          location = nil
          if (query =~ /^[0-9][0-9][0-9][0-9][0-9]$/)
            location = query
          else
            geonames_location = API::GeoNames::SearchJSON.search(query)
            if (geonames_location.found)
              location = geonames_location.to_wunderground
            end
          end
          if (!location.nil?)
            conditions = API::WUnderground::Q.get_current_conditions(location)
            if (conditions.found)
              msg  = "#{Colors.gray}[#{Colors.cyan}weather#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkcyan}#{conditions.location}#{Colors.gray}]#{Colors.reset} "
              msg += "#{conditions.weather.downcase}"
              msg += " #{Colors.gray}|#{Colors.reset}"
              msg += "#{weather_color(conditions.temp_f)} #{conditions.temp_f}f#{Colors.reset}"
              msg += " #{Colors.gray}|#{Colors.reset} "
              msg += "feels like:#{weather_color(conditions.feels_like_f)} #{conditions.feels_like_f}f#{Colors.reset}"
              msg += " #{Colors.gray}|#{Colors.reset} "
              msg += "humidity: #{conditions.relative_humidity}%"
              msg += " #{Colors.gray}|#{Colors.reset} "
              msg += "visibility: #{conditions.visibility_mi}mi"
              msg += " #{Colors.gray}|#{Colors.reset} "
              if (conditions.wind_mph > 0)
                msg += "winds: #{conditions.wind_mph}mph from #{conditions.wind_dir.downcase}"
                if (conditions.wind_gust_mph > 0)
                  msg += " (gusts up to #{conditions.wind_gust_mph}mph)"
                end
              else
                msg += 'winds: calm'
              end
              channel.message(msg)
            else
              channel.message("#{nick.name}: no weather data found for \"#{query}\".")
            end
          else
            channel.message("#{nick.name}: couldn't find a location matching \"#{query}\".")
          end
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
          channel.message("#{nick.name}: the weather guys can't report the weather for \"#{query}\" right now.")
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
