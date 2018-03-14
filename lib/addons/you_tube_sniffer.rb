require 'api/you_tube/v3.rb'
require 'uri_utils.rb'

module Axial
  module Addons
    class YouTubeSniffer < Axial::Addon

      def initialize()
        super

        @name    = 'youtube link sniffer'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel /https{0,1}:\/\/youtu\.be\/\S+/,          :handle_youtube
        on_channel /https{0,1}:\/\/www\.youtube\.com\/\S+/,  :handle_youtube
        on_channel /https{0,1}:\/\/m\.youtube\.com\/\S+/,    :handle_youtube
      end

      def handle_youtube(channel, nick, text)
        youtube_id = ""
        parsed_urls = Axial::URIUtils.extract(text)
        if (parsed_urls.count == 0)
          return
        end
        video_url = parsed_urls.first
        uri = URI.parse(video_url)
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

        if (youtube_id.empty?)
          log "Youtube video not found: #{video_url}"
          return
        else
          video = API::YouTube::V3.get_video(youtube_id)
          if (video.found)
            link = URIUtils.shorten(video_url)
            msg  = "#{$irc_gray}[#{$irc_blue}youtube#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkblue}#{nick.name}#{$irc_gray}]#{$irc_reset} "
            msg += video.title
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += video.duration.short_to_s
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += "#{video.view_count.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} views"
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += video.irc_description
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += link.to_s
            channel.message(msg)
          else
            log "Youtube video not found: #{video_url}"
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        log "#{self.class} error: #{ex.class}: #{ex.message}"
        ex.backtrace.each do |i|
          log i
        end
      end
    end
  end
end
