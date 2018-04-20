require 'axial/addon'
require 'axial/api/you_tube/v3'
require 'axial/uri_utils'

module Axial
  module Addons
    class YouTubeSniffer < Axial::Addon
      def initialize(bot)
        super

        @name                                                 = 'youtube video sniffer'
        @author                                               = 'sylence <sylence@sylence.org>'
        @version                                              = '1.1.0'

        throttle                                              5

        on_channel            %r[https{0,1}://youtu.be/\S+],  :sniff_youtube_link
        on_channel     %r[https{0,1}://www.youtube.com/\S+],  :sniff_youtube_link
        on_channel       %r[https{0,1}://m.youtube.com/\S+],  :sniff_youtube_link
      end

      def sniff_youtube_link(channel, nick, text)
        parsed_urls = URIUtils.extract(text)
        if (parsed_urls.empty?)
          return
        end
        video_url = parsed_urls.first
        video_uri = URI.parse(video_url)

        youtube_id = extract_youtube_id(video_uri)
        if (youtube_id.empty?)
          return
        end

        video = API::YouTube::V3.get_video(youtube_id)
        if (!video.found)
          return
        end

        send_youtube_to_channel(channel, video, video_url)
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def extract_youtube_id(video_uri)
        youtube_id = ''
        if (video_uri.host =~ /youtu\.be/)
          youtube_id = video_uri.path.gsub(%r[/], '')
        elsif (video_uri.host =~ /youtube\.com/)
          query = CGI.parse(video_uri.query)
          if (query.key?('v'))
            if (query['v'].is_a?(Array) && query['v'].any?)
              youtube_id = query['v'][0]
            end
          end
        end

        return youtube_id
      end

      def send_youtube_to_channel(channel, video, video_url) # rubocop:disable Metrics/AbcSize
        link = URIUtils.shorten(video_url)
        msg  = "#{Colors.gray}[#{Colors.red}youtube#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkred}#{nick.name}#{Colors.gray}]#{Colors.reset} "
        msg += video.title
        msg += " #{Colors.gray}|#{Colors.reset} "
        msg += video.duration.short_to_s
        msg += " #{Colors.gray}|#{Colors.reset} "
        msg += "#{video.view_count.to_s.reverse.gsub(/...(?=.)/, '\&,').reverse} views"
        msg += " #{Colors.gray}|#{Colors.reset} "
        msg += video.irc_description
        msg += " #{Colors.gray}|#{Colors.reset} "
        msg += link.to_s
        channel.message(msg)
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}", __FILE__, __LINE__)
        end
      end
    end
  end
end
