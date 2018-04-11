require 'uri'
require 'axial/uri_utils'

module Axial
  module API
    module Wikipedia
      WIKIPEDIA_PUBLIC_URL = 'https://en.wikipedia.org/'

      class Article
        attr_accessor :id, :extract, :json, :found

        def initialize()
          @id = ''
          @found = false
          @extract = ''
          @irc_extract = ''
          @json = ''
          @url = ''
        end

        def irc_extract()
          short_extract = URIUtils.strip_html(@extract)
          if (short_extract.length > 319)
            short_extract = short_extract[0..319] + '...'
          end
          return short_extract
        end

        def url()
          if (@id == '')
            return ''
          else
            params = Hash.new
            params[:curid] = @id.to_s
            url = URI.parse(WIKIPEDIA_PUBLIC_URL)
            url.query = URI.encode_www_form(params)
            return url.to_s
          end
        end
      end
    end
  end
end
