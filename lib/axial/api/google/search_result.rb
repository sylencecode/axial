require 'axial/uri_utils'
require 'json'

module Axial
  module API
    module Google
      class SearchResult
        attr_accessor :link, :snippet, :title
        def initialize()
          @link     = ''
          @snippet  = ''
          @title    = ''
        end

        def self.from_json(json)
          json_hash             = JSON.parse(json)
          result                = new
          result.link           = json_hash.dig('items')&.first&.dig('link') || 'no link found'

          twitter_description   = json_hash.dig('items')&.first&.dig('pagemap', 'metatags')&.first&.dig('twitter:description')
          default_snippet       = json_hash.dig('items')&.first&.dig('snippet') || 'no description'
          long_snippet_html     = twitter_description || default_snippet
          long_snippet          = URIUtils.strip_html(long_snippet_html)
          result.snippet        = (long_snippet.length <= 319) ? long_snippet : long_snippet[0..316] + '...'

          page_title            = json_hash.dig('items')&.first&.dig('title') || 'untitled'
          result.title          = (page_title.length <= 127) ? page_title : page_title[0..127]

          return result
        end
      end
    end
  end
end
