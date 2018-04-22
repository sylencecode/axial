gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

require 'axial/api/wunderground/conditions'

module Axial
  module API
    module WUnderground
      class Q
        @api_key = 'a584b01d4dbd0159'
        @rest_api = 'http://api.wunderground.com/api/' + @api_key + '/conditions/q'

        def self.get_current_conditions(in_location)
          if (!in_location.is_a?(String) || in_location.strip.empty?)
            raise(ArgumentError, "Invalid location provided to WUnderground: #{in_location.inspect}")
          end

          location = in_location.strip
          location.tr!(' ', '_')

          rest_endpoint = URI.parse(@rest_api + '/' + location + '.json')
          json = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)

          json_hash = parse_with_redirects(json)

          conditions = WUnderground::Conditions.from_json_hash(json_hash)
          return conditions
        end

        def self.parse_with_redirects(json)
          json_hash = JSON.parse(json)
          if (!json_hash.key?('response'))
            return {}
          end

          if (!json_hash.key?('current_observation'))
            json_hash = follow_redirect(json_hash)
          end

          return json_hash
        end

        def self.follow_redirect(json_hash)
          redirect_array = json_hash.dig('response', 'results')
          if (redirect_array.empty?)
            return json_hash
          end

          redirect_element = redirect_array.first
          if (!redirect_element.key?('l'))
            return json_hash
          end

          new_location = redirect_element.dig('l').delete_prefix('/q/')
          new_uri = URI.parse(@rest_api + '/' + new_location + '.json')

          new_response = RestClient::Request.execute(method: :get, url: new_uri.to_s, verify_ssl: false)
          new_json_hash = JSON.parse(new_response)
          return new_json_hash
        end
      end
    end
  end
end
