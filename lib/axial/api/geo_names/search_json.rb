gem 'rest-client'

require 'rest-client'
require 'uri'
require 'json'
require 'axial/api/geo_names/location'

module Axial
  module API
    module GeoNames
      class SearchJSON
        @geonames_user = 'donovanandersen'
        @rest_api = 'http://api.geonames.org/searchJSON'

        def self.default_params()
          default_params = {
            username: @geonames_user,
            maxRows:  1
          }

          return default_params
        end

        def self.search(in_query)
          if (!in_query.is_a?(String) || in_query.strip.empty?)
            raise(ArgumentError, "Invalid query provided to #{self.class}: #{in_query.inspect}")
          end

          query = in_query.strip

          params                = default_params
          params[:q]            = query

          rest_endpoint         = URI.parse(@rest_api)
          rest_endpoint.query   = URI.encode_www_form(params)

          json  = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)
          result = API::GeoNames::Location.from_json(json)

          return result
        end
      end
    end
  end
end
