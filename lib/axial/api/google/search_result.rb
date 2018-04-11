require 'axial/uri_utils'

module Axial
  module API
    module Google
      class SearchResult
        attr_reader :link, :snippet, :title
        def initialize(link, snippet, title)
          @link     = link
          @snippet  = snippet
          @title    = title
        end

        def self.from_json(json)
          link                  = json.dig('items')&.first&.dig('link') || 'no link found'

          twitter_description   = json.dig('items')&.first&.dig('pagemap', 'metatags')&.first&.dig('twitter:description')
          default_snippet       = json.dig('items')&.first&.dig('snippet') || 'no description'
          long_snippet_html     = twitter_description || default_snippet
          long_snippet          = URIUtils.strip_html(long_snippet_html)
          snippet               = (long_snippet.length <= 319) ? long_snippet : long_snippet[0..316] + '...'

          page_title            = json.dig('items')&.first&.dig('title') || 'untitled'
          title                 = (page_title.length <= 127) ? page_title : page_title[0..127]

          return new(link, snippet, title)
        end
      end
    end
  end
end
