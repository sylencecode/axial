gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

$google_api_key = "AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs"

module Axial
  module API
    module Google
      module URLShortener
        class V1
          @google_rest_api = "https://www.googleapis.com/urlshortener/v1/url"
  
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
        
            response = RestClient.post(rest_endpoint.to_s, payload.to_json, headers)
            json = JSON.parse(response)

            short_url = nil
            if (json.has_key?('id'))
              short_url = json['id']
            end

            return URI.parse(short_url)
          rescue RestClient::Exception => ex
            return nil
          end
        end
      end
    end
  end
end
