gem 'rest-client'
gem 'nokogiri'
require 'rest-client'
require 'nokogiri'
require 'uri'
require 'json'
require 'axial/uri_utils'
require 'axial/api/wikipedia/article'

module Axial
  module API
    module Wikipedia
      class W
        @rest_api = 'https://en.wikipedia.org/w/api.php'

        def self.default_params()
          params = {
            action:     'query',
            prop:       'extracts',
            format:     'json',
            redirects:  1,
            exintro:    true
          }

          return params
        end

        def self.search(query)
          query = query.strip
          if (query.empty?)
            raise(ArgumentError, "Invalid query provided to Wikipedia: #{in_query.inspect}")
          end

          params              = default_params
          params[:titles]     = query

          rest_endpoint       = URI.parse(@rest_api)
          rest_endpoint.query = URI.encode_www_form(params)
          json                = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)

          article = API::Wikipedia::Article.from_json(json)
          return article
        end
      end
    end
  end
end
