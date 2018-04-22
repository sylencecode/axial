gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

module Axial
  module API
    module Google
      module URLShortener
        class V1
          @rest_api = 'https://www.googleapis.com/urlshortener/v1/url'
          @api_key  = 'AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs'

          def self.default_headers()
            headers = {
                content_type: 'application/json',
                accept: 'application/json'
            }

            return headers
          end

          def self.default_params()
            params = {
                fields: 'id',
                key: @api_key
            }

            return params
          end

          def self.shorten(long_url)
            headers = default_headers
            params  = default_params

            rest_endpoint = URI.parse(@rest_api)
            rest_endpoint.query  = URI.encode_www_form(params)

            payload = {
              longUrl: long_url.to_s
            }

            json = RestClient::Request.execute(method: :post, headers: headers, payload: payload.to_json, url: rest_endpoint.to_s, verify_ssl: false)
            json_hash = JSON.parse(json)

            short_uri = (json_hash.key?('id')) ? URI.parse(json_hash['id']) : nil

            return short_uri
          rescue RestClient::Exception
            return nil
          end
        end
      end
    end
  end
end
