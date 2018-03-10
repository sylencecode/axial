require 'geonames/api/search_json.rb'
require 'wunderground/api/q.rb'

module Axial
  module Addons
    class Weather < Axial::Addon

      def initialize()
        super

        @name    = 'weather underground'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?weather', :handle_weather
        on_channel '?w', :handle_weather
      end
      
      def weather_color(temp)
        if (temp >= 90)
          temp_color = $irc_red
        elsif (temp >= 70)
          temp_color = $irc_yellow
        elsif (temp <= 40)
          temp_color = $irc_blue
        elsif (temp <= 60)
          temp_color = $irc_cyan
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
          log "weather request from #{nick.uhost}: #{query}"
          location_search = ::GeoNames::API::SearchJSON.new
          geonames_location = location_search.search(query)
          if (geonames_location.found)
            search = ::WUnderground::API::Conditions::Q.new
            conditions = search.get_current_conditions(geonames_location.to_wunderground)
            if (conditions.found)
              msg  = "#{$irc_gray}[#{$irc_cyan}weather#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkcyan}#{conditions.location}#{$irc_gray}]#{$irc_reset} "
              msg += "#{conditions.weather.downcase}"
              msg += " #{$irc_gray}|#{$irc_reset}"
              msg += "#{weather_color(conditions.temp_f)} #{conditions.temp_f}f#{$irc_reset}"
              msg += " #{$irc_gray}|#{$irc_reset} "
              msg += "feels like:#{weather_color(conditions.feels_like_f)} #{conditions.feels_like_f}f#{$irc_reset}"
              msg += " #{$irc_gray}|#{$irc_reset} "
              msg += "humidity: #{conditions.relative_humidity}%"
              msg += " #{$irc_gray}|#{$irc_reset} "
              msg += "visibility: #{conditions.visibility_mi}mi"
              msg += " #{$irc_gray}|#{$irc_reset} "
              if (conditions.wind_mph > 0)
                msg += "winds: #{conditions.wind_mph}mph from #{conditions.wind_dir.downcase}"
                if (conditions.wind_gust_mph > 0)
                  msg += " (gusts up to #{conditions.wind_gust_mph}mph)"
                end
              else
                msg += "winds: calm"
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
          log "#{self.class} error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
          channel.message("#{nick.name}: the weather guys can't report the weather for \"#{query}\" right now.")
        end
      end
    end
  end
end
