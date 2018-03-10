require 'rest-client'
require 'uri'
require 'json'

require_relative '../conditions.rb'
require_relative '../../handlers/logging.rb'

$wunderground_api_key = "a584b01d4dbd0159"

module WUnderground
  module API
    module Conditions
      class Q
        @@rest_api = "http://api.wunderground.com/api/#{$wunderground_api_key}/conditions/q"
  
        def get_current_conditions(in_location)
          if (!in_location.kind_of?(String) || in_location.strip.empty?)
            raise(ArgumentError, "Invalid location provided to WUnderground: #{in_location.inspect}")
          end
  
          location = in_location.strip
          location.gsub!(/ /, '_')
          uri = URI::parse(@@rest_api + "/" + location + ".json")
    
          response = RestClient.get(uri.to_s)
          orig_json = JSON.parse(response)
          new_json = ""

          if (orig_json.has_key?('response') && !orig_json.has_key?('current_observation'))
            response = orig_json['response']
            if (response.has_key?('results') && response['results'].kind_of?(Array))
              results = response['results']
              if (results.count > 0)
                result = results[0]
                if (result.has_key?('l'))
                  redirect = result['l'].gsub(/^\/q\//, '')
                  new_uri = URI::parse(@@rest_api + "/" + redirect + ".json")
                  new_response = RestClient.get(new_uri.to_s)
                  new_json = JSON.parse(new_response)
                end
              end
            end
          end

          if (!new_json.empty?)
            json = new_json
          else
            json = orig_json
          end

          conditions = WUnderground::Conditions.new
          conditions.json = json
  
          if (json.has_key?('current_observation'))
            observation = json['current_observation']
            if (observation.count > 1)
              conditions.found = true
            end
            if (observation.has_key?('feelslike_c'))
              conditions.feels_like_c = observation['feelslike_c'].to_i
            end
            if (observation.has_key?('feelslike_f'))
              conditions.feels_like_f = observation['feelslike_f'].to_i
            end
            if (observation.has_key?('display_location'))
              display_location = observation['display_location']
              if (display_location.has_key?('full'))
                conditions.location = display_location['full']
              end
            end
            if (observation.has_key?('relative_humidity'))
              if (observation['relative_humidity'] =~ /(\d+)/)
                conditions.relative_humidity = $1.to_i
              end
            end
            if (observation.has_key?('temp_c'))
              conditions.temp_c = observation['temp_c'].to_i
            end
            if (observation.has_key?('temp_f'))
              conditions.temp_f = observation['temp_f'].to_i
            end
            if (observation.has_key?('visibility_mi'))
              conditions.visibility_mi = observation['visibility_mi'].to_i
            end
            if (observation.has_key?('weather'))
              conditions.weather = observation['weather']
            end
            if (observation.has_key?('weather'))
              if (observation['wind_dir'].downcase == 'variable')
                conditions.wind_dir = 'various directions'
              else
                conditions.wind_dir = "the #{observation['wind_dir']}"
              end
            end
            if (observation.has_key?('wind_gust_mph'))
              conditions.wind_gust_mph = observation['wind_gust_mph'].to_i
            end
            if (observation.has_key?('wind_mph'))
              conditions.wind_mph = observation['wind_mph'].to_i
            end
          end
          return conditions
        end
      end
    end
  end
end
