# NOTE: this requires a paid subscription

require 'rest-client'
require 'uri'
require 'json'

$google_api_key = "AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs"

module Axial
  module API
    module Google
      module Translate
        class V2
          @google_rest_api = "https://translation.googleapis.com/language/translate/v2"
  
          def self.translate(source_language, target_language, text)
            rest_endpoint = URI.parse(@google_rest_api)
        
            params = {
              key: $google_api_key
            }
            rest_endpoint.query  = URI.encode_www_form(params)
        
            headers = {
              content_type: 'application/json',
                    accept: 'application/json'
            }
        
            payload = {
              source: source_language,
              target: target_language,
                   q: [
                        text
                    ]
            }
        
            response = RestClient.post(rest_endpoint.to_s, payload.to_json, headers)
            json = JSON.parse(response)
            puts JSON.pretty_inspect(json)
        
            translation = nil
            if (json.has_key?('data'))
              data = json.data
              if (data.has_key?('translations'))
                translations = data['translations']
                if (translations.is_a?(Array) && translations.count > 0)
                  translation = translations.first
                end
              end
            end
            return translation
          rescue RestClient::Exception => ex
            puts "#{ex.class}: #{ex.message}"
            return nil
          end
        end
      end
    end
  end
end
