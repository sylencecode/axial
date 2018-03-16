gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

require 'api/google/search_result.rb'

$google_api_key = "AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs"

module Axial
  module API
    module Google
      module CustomSearch
        class V1
          @rest_api = "https://www.googleapis.com/customsearch/v1"
          @custom_search_engine = "017601080673594609581:eywkykmajmc"

          def self.default_params()
            params = {}
            params[:cx]         = @custom_search_engine
            params[:filter]     = 1 
            params[:num]        = 1 
            params[:key]        = $google_api_key
            return params
          end
    
          def self.image_search(in_query)
            if (!in_query.kind_of?(String) || in_query.strip.empty?)
              raise(ArgumentError, "Invalid query provided to Google Custom Search: #{in_query.inspect}")
            end
    
            query               = in_query.strip
            params              = default_params
            params[:q]          = query
            params[:searchType] = 'image'

            uri = URI::parse(@rest_api)
            uri.query = URI.encode_www_form(params)
            response = RestClient.get(uri.to_s)
            json = JSON.parse(response)
            result = API::Google::SearchResult.new
            result.json = json
            
            if (json.has_key?('items'))
              items = json['items']
              if (items.count > 0)
                item = items.first
                if (item.kind_of?(Hash))
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

          def self.search(in_query)
            if (!in_query.kind_of?(String) || in_query.strip.empty?)
              raise(ArgumentError, "Invalid query provided to Google Custom Search: #{in_query.inspect}")
            end
    
            query      = in_query.strip
            params     = default_params
            params[:q] = query

            uri = URI::parse(@rest_api)
            uri.query = URI.encode_www_form(params)
            response = RestClient.get(uri.to_s)
            json = JSON.parse(response)
            result = API::Google::SearchResult.new
            result.json = json
            
            if (json.has_key?('items'))
              items = json['items']
              if (items.count > 0)
                item = items.first
                if (item.kind_of?(Hash))
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
                    title = item['title']
                    if (title.length > 127)
                      title = title[0..127]
                    end
                    result.title = title
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
  end
end
