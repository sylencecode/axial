require 'rest-client'
require 'uri'
require 'json'

require_relative '../article.rb'

module Wikipedia
  module API
    class W
      @@rest_api = "https://en.wikipedia.org/w/api.php"
  
      def search(in_query)
        if (!in_query.kind_of?(String) || in_query.strip.empty?)
          raise(ArgumentError, "Invalid query provided to Wikipedia: #{in_query.inspect}")
        end

        query = in_query.strip
        params = Hash.new
        params[:action]    = "query"
        params[:prop]      = "extracts"
        params[:format]    = "json"
        params[:titles]    = query
        params[:redirects] = 1 
        params[:exintro]   = true
        uri = URI::parse(@@rest_api)
        uri.query = URI.encode_www_form(params)
        response = RestClient.get(uri.to_s)
        json = JSON.parse(response)
        article = Wikipedia::Article.new
        article.json = json
  
        if (json.has_key?('query'))
          query = json['query']
          if (query.has_key?('pages') && query['pages'].kind_of?(Hash))
            pages = query['pages']
            if (pages.count > 0)
              page = pages.values[0]
              if (page.has_key?('pageid'))
                article.found = true
                article.id = page['pageid']
                if (page.kind_of?(Hash) && page.has_key?('extract'))
                  article.extract = page['extract']
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
