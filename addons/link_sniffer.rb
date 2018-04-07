require 'axial/addon'
require 'axial/uri_utils'
require 'axial/api/link_preview'
require 'axial/api/web_of_trust/v0_4/public_link_json2'

module Axial
  module Addons
    class LinkSniffer < Axial::Addon

      def initialize(bot)
        super

        @name    = 'link sniffer'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        throttle 5

        on_channel_leftover /https{0,1}:\/\/\S+/,   :sniff_link
      end

      def sniff_link(channel, nick, text)
        urls = URIUtils.extract(text)
        if (urls.any?)
          warnings = []
          begin
            warnings  = Axial::API::WebOfTrust::V0_4::PublicLinkJSON2.get_rating(urls.first)
          rescue
          end

          preview = API::LinkPreview.preview(urls.first)
          if (!preview.nil? && preview.data?)
            msg  = "#{Colors.gray}[#{Colors.green}link#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkgreen}#{nick.name}#{Colors.gray}]#{Colors.reset} "
            msg += preview.title
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += preview.short_description
            msg += " #{Colors.gray}|#{Colors.reset} "
            if (warnings.any?)
              msg += preview.url
              msg += " #{Colors.gray}[#{Colors.red}potentially #{warnings.join(', ')}#{Colors.gray}]#{Colors.reset}"
            else
              msg += URIUtils.shorten(preview.url)
            end
            channel.message(msg)
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

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
