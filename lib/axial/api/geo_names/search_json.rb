gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

require 'axial/api/geo_names/search_result'

$geonames_user = 'donovanandersen'

module Axial
  module API
    module GeoNames
      class SearchJSON
        @rest_api = 'http://api.geonames.org/searchJSON'

        def self.search(in_query)
          if (!in_query.is_a?(String) || in_query.strip.empty?)
            raise(ArgumentError, "Invalid query provided to #{self.class}: #{in_query.inspect}")
          end

          query = in_query.strip
          params = {}
          params[:username]  = $geonames_user
          params[:q]         = query
          params[:maxRows]   = 1
          rest_endpoint = URI.parse(@rest_api)
          rest_endpoint.query = URI.encode_www_form(params)
          response = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)
          json = JSON.parse(response)

          result = API::GeoNames::SearchResult.new

          if (json.key?('totalResultsCount'))
            result_count = json['totalResultsCount'].to_i
            if (result_count.positive?)
              geonames = json['geonames']
              if (geonames.is_a?(Array) && geonames.any?)
                result.found = true
                geoname = geonames[0]
                if (geoname.key?('countryCode'))
                  result.country_code = geoname['countryCode'].upcase
                end
                if (geoname.key?('countryId'))
                  result.country_id = geoname['countryId'].upcase
                end
                if (geoname.key?('adminCode1'))
                  result.admin_code1 = geoname['adminCode1'].upcase
                end
                if (geoname.key?('name'))
                  result.city = geoname['name']
                end
                if (geoname.key?('lat'))
                  result.lat = geoname['lat'].to_f
                end
                if (geoname.key?('lng'))
                  result.long = geoname['lng'].to_f
                end
              end
            end
          end
          return result
        end
      end
    end
  end
end
