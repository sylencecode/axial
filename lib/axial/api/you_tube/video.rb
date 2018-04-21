require 'axial/timespan'

module Axial
  module API
    module YouTube
      class Video
        attr_accessor :id, :title, :duration, :view_count, :found, :description, :link
        def initialize()
          @found = false
          @id = 'unknown id'
          @title = 'unknown title'
          @view_count = 0
          @duration = TimeSpan.empty
          @description = ''
          @link = ''
        end

        def irc_description()
          short_description = @description.strip
          short_description = short_description.gsub(/\s+/, ' ')
          if (short_description.length > 239)
            short_description = URIUtils.strip_html(short_description)
            short_description = short_description[0..239] + '...'
          end
          return short_description
        end
      end
    end
  end
end
