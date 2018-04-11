gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'
require 'axial/api/you_tube/video'

module Axial
  module API
    module YouTube
      class V3
        @youtube_key = 'AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs'
        @rest_api = 'https://www.googleapis.com/youtube/v3/videos'

        def self.get_video(id)
          params = {}
          params[:part]    = 'snippet,contentDetails,statistics'
          params[:id]      = id
          params[:fields]  = 'items(id,contentDetails/duration,statistics/viewCount,snippet/title,snippet/description)'
          params[:key]     = @youtube_key
          rest_endpoint = URI.parse(@rest_api)
          rest_endpoint.query = URI.encode_www_form(params)
          video = API::YouTube::Video.new
          response = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)
          json = JSON.parse(response)
          video.json = json
          if (json.key?('items') && json['items'].is_a?(Array))
            items = json['items']
            if (items.any?)
              video.found = true
              item = items[0]
              if (item.key?('id') && item['id'].is_a?(String))
                video.id = item['id']
              end
              if (item.key?('snippet') && item['snippet'].is_a?(Hash))
                snippet = item['snippet']
                if (snippet.key?('title') && snippet['title'].is_a?(String))
                  video.title = snippet['title']
                end
                if (snippet.key?('description') && snippet['description'].is_a?(String))
                  video.description = snippet['description']
                end
              end
              if (item.key?('statistics') && item['statistics'].is_a?(Hash))
                statistics = item['statistics']
                if (statistics.key?('viewCount'))
                  viewcount = statistics['viewCount'].to_i
                  video.view_count = viewcount
                end
              end
              if (item.key?('contentDetails') && item['contentDetails'].is_a?(Hash))
                content_details = item['contentDetails']
                if (content_details.key?('duration') && content_details['duration'].is_a?(String) && !content_details['duration'].empty?)
                  duration = content_details['duration'].strip.downcase
                  if (duration =~ /^pt(.*)/)
                    raw_duration = Regexp.last_match[1]
                    if (raw_duration =~ /(\d+)h/)
                      video.duration.hours = Regexp.last_match[1].to_i
                    end
                    if (raw_duration =~ /(\d+)m/)
                      video.duration.minutes = Regexp.last_match[1].to_i
                    end
                    if (raw_duration =~ /(\d+)s/)
                      video.duration.seconds = Regexp.last_match[1].to_i
                    end
                  end
                end
              end
            end
          end
          return video
        end
      end
    end
  end
end
