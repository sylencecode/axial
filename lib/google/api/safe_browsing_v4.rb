require 'rest-client'
require 'uri'
require 'json'

module Filters
  class GoogleSafeBrowsingAPI
    @@google_api_key = "AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs"
    @@rest_api = "https://safebrowsing.googleapis.com/v4/threatMatches:find"

    def safe_uri?(in_uri)
        if (in_uri.kind_of?(String))
          uri = in_uri.strip
          if (uri.empty?)
            raise(ArgumentError, "Empty URI provided to SafeBrowsingAPI")
          elsif (!(uri =~ URI::regexp))
            raise(ArgumentError, "Invalid URI provided to SafeBrowsingAPI: #{uri}")
          end
        else
          raise(ArgumentError, "Invalid object provided to SafeBrowsingAPI: #{in_uri.class}")
        end
      safe = false

      site_uri = URI::parse(uri)

      params = Hash.new
      params[:key]              = @@google_api_key

      rest_endpoint = URI::parse(@@rest_api)
      rest_endpoint.query = URI.encode_www_form(params)

      headers = {
        :content_type => 'application/json',
        :accept => 'application/json'
      }
      payload = {
        :client => {
          :clientId => "axial",
          :clientVersion => "0.1"
        },
        :threatInfo => {
          :threatTypes => [ "MALWARE", "SOCIAL_ENGINEERING", "POTENTIALLY_HARMFUL_APPLICATION" ],
          :platformTypes => [ "ANY_PLATFORM" ],
          :threatEntryTypes => [ "URL" ],
          :threatEntries => [
            {
              :url => site_uri.to_s
            }
          ]
        }
      }

      response = RestClient.post(rest_endpoint.to_s, payload.to_json, headers)
      json = JSON.parse(response)
      if (json.has_key?('matches') && json['matches'].kind_of?(Array) && json['matches'].count > 0)
        safe = false
      else
        safe = true
      end
      return safe
    end
  end
end
