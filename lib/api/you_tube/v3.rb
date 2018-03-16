gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'
require 'uri_utils.rb'
require 'api/you_tube/video.rb'

module Axial
  module API
    module YouTube
      class V3
        @youtube_key = "AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs"
        @rest_api = "https://www.googleapis.com/youtube/v3/videos"
    
        def self.get_video(id)
          params = Hash.new
          params[:part]    = "snippet,contentDetails,statistics"
          params[:id]      = id
          params[:fields]  = "items(id,contentDetails/duration,statistics/viewCount,snippet/title,snippet/description)"
          params[:key]     = @youtube_key
          uri = URI::parse(@rest_api)
          uri.query = URI.encode_www_form(params)
          video = Axial::API::YouTube::Video.new
          response = RestClient.get(uri.to_s)
          json = JSON.parse(response)
          video.json = json
          if (json.has_key?('items') && json['items'].kind_of?(Array))
            items = json['items']
            if (items.count > 0)
              video.found = true
              item = items[0]
              if (item.has_key?('id') && item['id'].kind_of?(String))
                video.id = item['id']
              end
              if (item.has_key?('snippet') && item['snippet'].kind_of?(Hash))
                snippet = item['snippet']
                if (snippet.has_key?('title') && snippet['title'].kind_of?(String))
                  video.title = snippet['title']
                end
                if (snippet.has_key?('description') && snippet['description'].kind_of?(String))
                  video.description = snippet['description']
                end
              end
              if (item.has_key?('statistics') && item['statistics'].kind_of?(Hash))
                statistics = item['statistics']
                if (statistics.has_key?('viewCount'))
                  viewcount = statistics['viewCount'].to_i
                  video.view_count = viewcount
                end
              end
              if (item.has_key?('contentDetails') && item['contentDetails'].kind_of?(Hash))
                contentDetails = item['contentDetails']
                if (contentDetails.has_key?('duration') && contentDetails['duration'].kind_of?(String) && !contentDetails['duration'].empty?)
                  duration = contentDetails['duration'].strip.downcase
                  if (duration =~ /^pt(.*)/)
                    raw_duration = $1
                    if (raw_duration =~ /(\d+)h/)
                      video.duration.hours = $1.to_i
                    end
                    if (raw_duration =~ /(\d+)m/)
                      video.duration.minutes = $1.to_i
                    end
                    if (raw_duration =~ /(\d+)s/)
                      video.duration.seconds = $1.to_i
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
