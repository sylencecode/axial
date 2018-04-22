module Axial
  module API
    module WUnderground
      class Conditions
        attr_writer :found
        attr_accessor :feels_like_c, :feels_like_f, :location, :relative_humidity, :temp_c, :temp_f, :visibility_mi, :weather, :wind_dir, :wind_gust_mph, :wind_mph

        def initialize()
          @found = false
        end

        def found?()
          return @found
        end

        def self.from_json_hash(json)
          if (!json.key?('current_observation'))
            return nil
          end

          conditions = new

          observation = json.dig('current_observation')
          if (observation.count <= 1)
            return conditions
          end

          conditions.found = true
          conditions.load_observation_metadata(observation)
          conditions.load_temp_from_observation(observation)
          conditions.load_wind_from_observation(observation)
          return conditions
        end

        def load_observation_metadata(observation)
          @relative_humidity  = observation.dig('relative_humidity')&.to_i  || 0
          @location           = observation.dig('display_location', 'full') || 'unknown'
          @visibility_mi      = observation.dig('visibility_mi')&.to_i      || 0
          @weather            = observation.dig('weather')                  || 'conditions unknown'
        end

        def load_wind_from_observation(observation)
          @wind_gust_mph      = observation.dig('wind_gust_mph')&.to_i      || 0
          @wind_mph           = observation.dig('wind_mph')&.to_i           || 0

          wind_dir            = observation.dig('wind_dir')
          @wind_dir           = (wind_dir.casecmp('variable').zero?) ? 'several directions' : 'the ' + wind_dir
        end

        def load_temp_from_observation(observation)
          @feels_like_c       = observation.dig('feelslike_c')&.to_i        || 0
          @feels_like_f       = observation.dig('feelslike_f')&.to_i        || 0
          @temp_c             = observation.dig('temp_c')&.to_i             || 0
          @temp_f             = observation.dig('temp_f')&.to_i             || 0
        end
      end
    end
  end
end
