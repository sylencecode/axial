require 'uri'
require 'string/cleanup.rb'

module Axial
  module API
    module Wikipedia
      class Article
        attr_accessor :id, :extract, :json, :found
        @@wikipedia_web_url = "https://en.wikipedia.org/"
        def initialize()
          @id = ""
          @found = false
          @extract = ""
          @irc_extract = ""
          @json = ""
          @url = ""
        end
    
        def irc_extract()
          short_extract = @extract.cleanup
          if (short_extract.length > 319)
            short_extract = short_extract[0..319] + "..."
          end
          return short_extract
        end
    
        def url()
          if (@id == "")
            return ""
          else
            params = Hash.new
            params[:curid] = @id.to_s
            url = URI::parse(@@wikipedia_web_url)
            url.query = URI.encode_www_form(params)
            return url.to_s
          end
        end
      end
    end
  end
end
