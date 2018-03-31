require 'axial/addon'
require 'axial/api/you_tube/v3'
require 'axial/uri_utils'

module Axial
  module Addons
    class YouTubeSniffer < Axial::Addon

      def initialize(bot)
        super

        @name    = 'youtube video sniffer'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        on_channel /https{0,1}:\/\/youtu\.be\/\S+/,          :handle_youtube
        on_channel /https{0,1}:\/\/www\.youtube\.com\/\S+/,  :handle_youtube
        on_channel /https{0,1}:\/\/m\.youtube\.com\/\S+/,    :handle_youtube
      end

      def handle_youtube(channel, nick, text)
        youtube_id = ""
        parsed_urls = URIUtilsUtils.extract(text)
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
          LOGGER.warn("Youtube video not found: #{video_url}")
          return
        else
          video = API::YouTube::V3.get_video(youtube_id)
          if (video.found)
            link = URIUtils.shorten(video_url)
            msg  = "#{Colors.gray}[#{Colors.red}youtube#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkred}#{nick.name}#{Colors.gray}]#{Colors.reset} "
            msg += video.title
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += video.duration.short_to_s
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += "#{video.view_count.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse} views"
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += video.irc_description
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += link.to_s
            channel.message(msg)
          else
            LOGGER.warn("Youtube video not found: #{video_url}")
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
