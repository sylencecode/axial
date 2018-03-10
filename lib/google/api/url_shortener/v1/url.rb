require 'rest-client'
require 'uri'
require 'json'

$google_api_key = "AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs"

module Google
  module API
    module URLShortener
      module V1
        class URL
          @@rest_api = "https://www.googleapis.com/urlshortener/v1/url"
          @@do_not_shorten = Regexp.union([
            'youtu.be',
            'goo.gl',
            'tinyurl.com',
            'bit.ly',
            't.co'
          ])
    
          def shorten(in_url)
            if (in_url.kind_of?(String))
              stripped_url = in_url.strip
              if (stripped_url.empty?)
                raise(ArgumentError, "Empty URI provided to URLShortenerAPI")
              elsif (!(stripped_url =~ URI::regexp))
                raise(ArgumentError, "Invalid URI provided to URLShortenerAPI: #{in_url}")
              end
            else
              raise(ArgumentError, "Invalid object provided to URLShortenerAPI: #{in_url.class}")
            end
    
            long_url = URI.parse(stripped_url)
            if (@@do_not_shorten.match(long_url.host))
              return long_url.to_s
            end
    
            params = Hash.new
            params[:fields]      = "id"
            params[:key]         = $google_api_key
            rest_endpoint = URI::parse(@@rest_api)
            rest_endpoint.query = URI.encode_www_form(params)
            headers = {
              :content_type => 'application/json',
              :accept => 'application/json'
            }
            payload = {
              :longUrl => long_url.to_s
            }
            response = RestClient.post(rest_endpoint.to_s, payload.to_json, headers)
            json = JSON.parse(response)
            if (json.has_key?('id'))
              short_url = json['id']
            else
              short_url = nil
            end
            return short_url
          end
        end
      end
    end
  end
end
