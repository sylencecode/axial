require 'axial/timespan'

module Axial
  module API
    module YouTube
      class Video
        attr_accessor :id, :title, :duration, :view_count, :description, :link
        attr_writer :found

        def initialize()
          @duration = TimeSpan.empty
        end

        def found?()
          return (!@id.empty?)
        end

        def load_snippet(snippet)
          title             = snippet.dig('title')        || 'untitled video'
          description_html  = snippet.dig('description')  || 'no description'
          description       = URIUtils.strip_html(description_html)

          @title            = (title.length <= 120) ? title : title[0..116] + '...'
          @description      = (description.length <= 240) ? description : description[0..236] + '...'
        end

        def load_statistics(statistics)
          @view_count       = statistics.dig('viewCount')&.to_i || 0
        end

        def load_content_details(content_details)
          pt_string = content_details.dig('duration')&.strip&.downcase
          if (pt_string.nil?)
            return
          end

          @duration = TimeSpan.from_pt_string(pt_string)
        end

        def self.from_json(json)
          json_hash = JSON.parse(json)
          video = new

          items = json_hash.dig('items') || []
          if (items.empty?)
            return video
          end

          item = items.first

          video.found = true
          video.id = item.dig('id') || ''
          video.load_snippet(item.dig('snippet'))
          video.load_statistics(item.dig('statistics'))
          video.load_content_details(item.dig('contentDetails'))

          return video
        end
      end
    end
  end
end
