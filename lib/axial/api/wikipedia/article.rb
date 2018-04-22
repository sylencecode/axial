require 'json'
require 'uri'
require 'axial/uri_utils'

module Axial
  module API
    module Wikipedia
      WIKIPEDIA_PUBLIC_URL = 'https://en.wikipedia.org/'.freeze

      class Article
        attr_accessor :id, :extract
        attr_writer :found

        def initialize()
          @found = false
        end

        def found?()
          return @id.empty?
        end

        def irc_extract()
          short_extract = (@extract.length <= 300) ? @extract : @extract[0..296] + '...'
          return short_extract
        end

        def url()
          if (!found?)
            return ''
          end

          params = {
            curid: @id.to_s
          }

          url = URI.parse(WIKIPEDIA_PUBLIC_URL)
          url.query = URI.encode_www_form(params)

          return url.to_s
        end

        def self.from_json(json)
          json_hash         = JSON.parse(json)
          article           = new

          pages             = json_hash.dig('query', 'pages') || []
          page              = pages.is_a?(Hash) ? pages.values.first : {}

          article.id        = page.dig('pageid').to_s || ''

          extract           = page.dig('extract') || ''
          article.extract   = URIUtils.strip_html(extract)

          return article
        end
      end
    end
  end
end
