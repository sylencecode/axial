require 'axial/uri_utils'
require 'json'

module Axial
  module API
    module Google
      class SearchResult
        attr_accessor :link, :snippet, :title

        def self.from_json(json)
          json_hash         = JSON.parse(json)
          result            = new

          item              = json_hash.dig('items')&.first
          if (item.nil?)
            return result
          end

          meta_tags         = item.dig('pagemap', 'metatags')&.first

          long_snippet      = meta_tags&.dig('twitter:description') || item.dig('snippet')
          snippet           = URIUtils.strip_html(long_snippet)
          result.snippet    = (snippet.length <= 280) ? snippet : snippet[0..276] + '...'

          long_title        = item.dig('title') || 'untitled'
          title             = URIUtils.strip_html(long_title)
          result.title      = (title.length <= 120) ? title : title[0..116] + '...'

          result.link       = item.dig('link') || 'no link found'

          return result
        end
      end
    end
  end
end
