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

          json = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)
          video = API::YouTube::Video.from_json(json)

          return video
        end
      end
    end
  end
end
