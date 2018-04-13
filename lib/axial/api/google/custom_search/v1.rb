gem 'rest-client'
gem 'nokogiri'
require 'rest-client'
require 'nokogiri'
require 'uri'
require 'axial/api/google/search_result'
require 'axial/api/web_of_trust/v0_4/public_link_json2'

$google_api_key = 'AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs'

module Axial
  module API
    module Google
      module CustomSearch
        class V1
          @rest_api = 'https://www.googleapis.com/customsearch/v1'
          @custom_search_engine = '017601080673594609581:eywkykmajmc'

          @default_params = {
            cx:       @custom_search_engine,
            filter:   1,
            num:      1,
            key:      $google_api_key
          }

          def self.image_search(query)
            params                = @default_params.clone
            params[:q]            = query.strip
            params[:searchType]   = 'image'
            result = execute_search(params)
            return result
          end

          def self.search(query)
            params                = @default_params.clone
            params[:q]            = query.strip
            result = execute_search(params)
            return result
          end

          def self.execute_search(params)
            rest_endpoint = URI.parse(@rest_api)
            rest_endpoint.query = URI.encode_www_form(params)
            json = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)

            result = API::Google::SearchResult.from_json(json)
            return result
          end
        end
      end
    end
  end
end
