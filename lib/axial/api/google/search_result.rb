require 'axial/uri_utils'

module Axial
  module API
    module Google
      class SearchResult
        attr_accessor :link, :snippet, :title, :json
        def initialize()
          @link = ""
          @snippet = ""
          @title = ""
          @json = ""
        end
    
        def irc_snippet()
          short_snippet = URIUtils.strip_html(@snippet)
          if (short_snippet.length > 319)
            short_snippet = short_snippet[0..319] + "..."
          end
          return short_snippet
        end
      end
    end
  end
end
