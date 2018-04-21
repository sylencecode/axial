gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

require 'axial/api/wunderground/conditions'

$wunderground_api_key = 'a584b01d4dbd0159'

module Axial
  module API
    module WUnderground
      class Q
        @rest_api = "http://api.wunderground.com/api/#{$wunderground_api_key}/conditions/q"

        def self.get_current_conditions(in_location)
          if (!in_location.is_a?(String) || in_location.strip.empty?)
            raise(ArgumentError, "Invalid location provided to WUnderground: #{in_location.inspect}")
          end

          location = in_location.strip
          location.tr!(' ', '_')

          rest_endpoint = URI.parse(@rest_api + '/' + location + '.json')
          response = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)

          orig_json = JSON.parse(response)
          new_json = ''

          if (orig_json.key?('response') && !orig_json.key?('current_observation'))
            response = orig_json['response']
            if (response.key?('results') && response['results'].is_a?(Array))
              results = response['results']
              if (results.any?)
                result = results[0]
                if (result.key?('l'))
                  redirect = result['l'].gsub(/^\/q\//, '')
                  new_uri = URI.parse(@rest_api + '/' + redirect + '.json')
                  new_response = RestClient::Request.execute(method: :get, url: new_uri.to_s, verify_ssl: false)
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

          if (json.key?('current_observation'))
            observation = json['current_observation']
            if (observation.count > 1)
              conditions.found = true
            end
            if (observation.key?('feelslike_c'))
              conditions.feels_like_c = observation['feelslike_c'].to_i
            end
            if (observation.key?('feelslike_f'))
              conditions.feels_like_f = observation['feelslike_f'].to_i
            end
            if (observation.key?('display_location'))
              display_location = observation['display_location']
              if (display_location.key?('full'))
                conditions.location = display_location['full']
              end
            end
            if (observation.key?('relative_humidity'))
              if (observation['relative_humidity'] =~ /(\d+)/)
                conditions.relative_humidity = Regexp.last_match[1].to_i
              end
            end
            if (observation.key?('temp_c'))
              conditions.temp_c = observation['temp_c'].to_i
            end
            if (observation.key?('temp_f'))
              conditions.temp_f = observation['temp_f'].to_i
            end
            if (observation.key?('visibility_mi'))
              conditions.visibility_mi = observation['visibility_mi'].to_i
            end
            if (observation.key?('weather'))
              conditions.weather = observation['weather']
            end
            if (observation.key?('weather'))
              if (observation['wind_dir'].downcase == 'variable')
                conditions.wind_dir = 'various directions'
              else
                conditions.wind_dir = "the #{observation['wind_dir']}"
              end
            end
            if (observation.key?('wind_gust_mph'))
              conditions.wind_gust_mph = observation['wind_gust_mph'].to_i
            end
            if (observation.key?('wind_mph'))
              conditions.wind_mph = observation['wind_mph'].to_i
            end
          end
          return conditions
        end
      end
    end
  end
end
