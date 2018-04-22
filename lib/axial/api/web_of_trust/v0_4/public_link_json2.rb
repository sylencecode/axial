$stdout.sync = true
$stderr.sync = true

gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'
require 'axial/api/web_of_trust/rating'

module Axial
  module API
    module WebOfTrust
      REST_API = 'https://api.mywot.com'.freeze
      module V04
        REST_API = API::WebOfTrust::REST_API + '/0.4'
        class PublicLinkJSON2
          @rest_api = API::WebOfTrust::V04::REST_API + '/public_link_json2'
          @api_key  = 'f204e49afeeb0fd892e3a2643ceb1b7ea9e64a5e'

          def self.get_rating(in_uri)
            site_uri       = URI.parse(in_uri)
            site_host      = site_uri.host.downcase

            params         = {
              key:    @api_key,
              hosts:  site_host + '/'
            }

            rest_endpoint       = URI.parse(@rest_api)
            rest_endpoint.query = URI.encode_www_form(params)

            json                = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)
            rating              = API::WebOfTrust::Rating.from_json(json)
            puts rating.inspect

            return rating
          end
        end
      end
    end
  end
end
