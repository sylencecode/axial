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

        def self.search(in_query)
          if (!in_query.is_a?(String) || in_query.strip.empty?)
            raise(ArgumentError, "Invalid query provided to Wikipedia: #{in_query.inspect}")
          end

          query = in_query.strip
          params = {}
          params[:action]    = 'query'
          params[:prop]      = 'extracts'
          params[:format]    = 'json'
          params[:titles]    = query
          params[:redirects] = 1
          params[:exintro]   = true
          rest_endpoint = URI.parse(@rest_api)
          rest_endpoint.query = URI.encode_www_form(params)
          response = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)

          json = JSON.parse(response)

          article = API::Wikipedia::Article.new

          if (json.key?('query'))
            query = json['query']
            if (query.key?('pages') && query['pages'].is_a?(Hash))
              pages = query['pages']
              if (pages.any?)
                page = pages.values[0]
                if (page.key?('pageid'))
                  article.found = true
                  article.id = page['pageid']
                  if (page.is_a?(Hash) && page.key?('extract'))
                    article.extract = URIUtils.strip_html(page['extract'])
                  end
                end
              end
            end
          end
          return article
        end
      end
    end
  end
end
