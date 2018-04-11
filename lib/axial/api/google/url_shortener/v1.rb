gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

$google_api_key = 'AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs'

module Axial
  module API
    module Google
      module URLShortener
        class V1
          @google_rest_api = 'https://www.googleapis.com/urlshortener/v1/url'

          def self.shorten(long_url)
            rest_endpoint = URI.parse(@google_rest_api)

            params = {
              fields: 'id',
                 key: $google_api_key
            }
            rest_endpoint.query  = URI.encode_www_form(params)

            headers = {
              content_type: 'application/json',
                    accept: 'application/json'
            }

            payload = {
              longUrl: long_url.to_s
            }

            response = RestClient::Request.execute(method: :post, headers: headers, payload: payload.to_json, url: rest_endpoint.to_s, verify_ssl: false)
            json = JSON.parse(response)

            short_url = nil
            if (json.key?('id'))
              short_url = json['id']
            end

            return URI.parse(short_url)
          rescue RestClient::Exception
            return nil
          end
        end
      end
    end
  end
end
