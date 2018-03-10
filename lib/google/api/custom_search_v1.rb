require 'rest-client'
require 'uri'
require 'json'

require 'google/search_result.rb'

$google_api_key = "AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs"

module Google
  module API
    class CustomSearchV1
      @@rest_api = "https://www.googleapis.com/customsearch/v1"
      @@custom_search_engine = "017601080673594609581:eywkykmajmc"

      def search(in_query)
        if (!in_query.kind_of?(String) || in_query.strip.empty?)
          raise(ArgumentError, "Invalid query provided to Google Custom Search: #{in_query.inspect}")
        end

        query = in_query.strip
        params = Hash.new
        params[:q]         = query
        params[:cx]        = @@custom_search_engine
        params[:filter]    = 1 
        params[:num]       = 1 
        params[:key]       = $google_api_key
        uri = URI::parse(@@rest_api)
        uri.query = URI.encode_www_form(params)
        response = RestClient.get(uri.to_s)
#        response = File.read("/home/ircd/google/mangina.json")
        json = JSON.parse(response)
        result = Google::SearchResult.new
        result.json = json
        
        if (json.has_key?('items'))
          items = json['items']
          if (items.count > 0)
            item = items[0]
            if (item.kind_of?(Hash))
              if (item.has_key?('link'))
                result.link = item['link']
              end
              # might be able to get better description from metadata than the snippet itself
              if (item.has_key?('pagemap') && item['pagemap'].kind_of?(Hash))
                pagemap = item['pagemap']
                if (pagemap.has_key?('metatags') && pagemap['metatags'].kind_of?(Array))
                  metatags = pagemap['metatags'][0]
                  if (metatags.kind_of?(Hash))
                    if (metatags.has_key?('twitter:description'))
                      result.snippet = metatags['twitter:description']
                    end
                  end
                end
              end
              # fall back to the snippet if we didn't find any better description/summary
              if (result.snippet.empty? && item.has_key?('snippet'))
                result.snippet = item['snippet']
              end
              if (item.has_key?('title'))
                result.title = item['title']
              end
              if (item.has_key?('link'))
                result.link = item['link']
              end
            end
          end
        end

        return result
      end
    end
  end
end
