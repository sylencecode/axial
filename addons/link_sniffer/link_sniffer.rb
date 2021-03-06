require 'axial/addon'
require 'axial/uri_utils'
require 'axial/api/link_preview'
require 'axial/api/web_of_trust/v0_4/public_link_json2'

module Axial
  module Addons
    class LinkSniffer < Axial::Addon
      # rubocop:disable Style/PercentLiteralDelimiters,Style/RegexpLiteral
      def initialize(bot)
        super

        @name                                         = 'link sniffer'
        @author                                       = 'sylence <sylence@sylence.org>'
        @version                                      = '1.1.0'

        throttle                                      5

        # change to [] to send to all channels
        @restrict_to_channels = %w[ #lulz ]

        on_channel_leftover   %r[https{0,1}://\S+],   :sniff_link
        on_channel_leftover      %r[www\.\S+\.\S+],   :sniff_link
      end
      # rubocop:enable Style/PercentLiteralDelimiters,Style/RegexpLiteral

      def sniff_link(channel, nick, text)
        if (@restrict_to_channels.any? && !@restrict_to_channels.include?(channel.name.downcase))
          return
        end

        urls = URIUtils.extract(text)
        if (urls.any?)
          begin
            rating    = API::WebOfTrust::V04::PublicLinkJSON2.get_rating(urls.first)
            warnings  = rating.warnings
          rescue
            warnings  = []
          end

          preview = API::LinkPreview.preview(urls.first)
          if (preview&.data?)
            send_link_preview_to_channel(channel, nick, warnings, preview)
          else
            LOGGER.warn("failed to preview #{urls.first}")
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def send_link_preview_to_channel(channel, nick, warnings, preview)
        msg = Color.green_prefix('link', nick.name)
        msg += preview.title + Color.gray(' | ')
        msg += preview.description + Color.gray(' | ')
        if (warnings.any?) # rubocop:disable Style/ConditionalAssignment
          msg += preview.url + " #{Color.gray}[#{Color.red}potentially #{warnings.join(', ')}#{Color.gray(']')}"
        else
          msg += URIUtils.shorten(preview.url).to_s
        end
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
