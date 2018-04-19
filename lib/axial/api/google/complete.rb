gem 'rest-client'
require 'rest-client'
require 'uri'
require 'axial/api/google/complete_result'

module Axial
  module API
    module Google
      class Complete
        @rest_api = 'https://clients1.google.com/complete/search'
        @fake_client = 'iphonesafari'

        @default_params = {
            client:   @fake_client,
            json:     't'
        }

        def self.search(query)
          query       = query.strip
          params      = @default_params.clone

          params[:q]  = query.strip
          result      = execute_search(query, params)

          return result
        end

        def self.execute_search(query, params)
          rest_endpoint = URI.parse(@rest_api)
          rest_endpoint.query = URI.encode_www_form(params)
          json = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)

          json_array = JSON.parse(json)
          json_array.flatten!

          query_result_string = json_array.shift
          if (query_result_string.casecmp(query).zero?)
            json_array.collect!(&:strip)
            json_array.delete_if { |tmp_result| tmp_result.casecmp(query).zero? }
            result_array = json_array
            result = API::Google::CompleteResult.from_array(result_array)
          end

          return result
        end
      end
    end
  end
end
