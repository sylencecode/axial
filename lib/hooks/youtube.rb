require_relative '../youtube/api/video_v3.rb'
require_relative '../google/api/url_shortener/v1/url.rb'

#  @@youtube_matches = Regexp.union([
#    "youtu.be",
#    "youtube.com",
#  ])
#  if (@@youtube_matches.match(long_url.host))

module Axial
  module Hooks
    module YouTube
      def handle_youtube(nick, channel, in_uri)
        begin
          youtube_id = ""
          raw_uri = in_uri.strip
          encoded_uri = URI.encode(raw_uri)
          uri = URI.parse(encoded_uri)
          if (uri.host =~ /youtu\.be/)
            youtube_id = uri.path.gsub(/^\//, '')
          elsif (uri.host =~ /youtube\.com/)
            query = CGI.parse(uri.query)
            if (query.has_key?('v'))
              if (query['v'].kind_of?(Array))
                if (query['v'].count > 0)
                  youtube_id = query['v'][0]
                end
              end
            end
          end

          if (!youtube_id.empty?)
            search = ::YouTube::API::VideoV3.new
            video = search.get_video(youtube_id)
            if (video.found)
              url_shortener = ::Google::API::URLShortener::V1::URL.new
              short_url = url_shortener.shorten(uri.to_s)
              if (!short_url.empty?)
                link = short_url
              else
                link = uri.to_s
              end
              msg  = "#{$irc_gray}[#{$irc_blue}youtube#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkblue}#{nick}#{$irc_gray}]#{$irc_reset} "
              msg += video.title
              msg += " #{$irc_gray}|#{$irc_reset} "
              msg += video.duration.to_s
              msg += " #{$irc_gray}|#{$irc_reset} "
              msg += "#{video.view_count.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} views"
              msg += " #{$irc_gray}|#{$irc_reset} "
              msg += video.irc_description
              msg += " #{$irc_gray}|#{$irc_reset} "
              msg += link
              send_channel(channel, msg)
            else
              log "Youtube video not found: #{in_uri}"
            end
          end
        rescue Exception => ex
          log "Youtube error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end
    end
  end
end
