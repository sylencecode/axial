require 'axial/addon'
require 'axial/uri_utils'
require 'axial/api/google/custom_search/v1'
require 'axial/api/web_of_trust/v0_4/public_link_json2'

module Axial
  module Addons
    class GoogleSearch < Axial::Addon
      def initialize(bot)
        super

        @name                       = 'google custom search'
        @author                     = 'sylence <sylence@sylence.org>'
        @version                    = '1.1.0'

        throttle                    5

        on_channel 'gis',           :google_image_search
        on_channel 'image',         :google_image_search
        on_channel 'imagesearch',   :google_image_search
        on_channel 'google',        :google_search
        on_channel 'g',             :google_search
      end

      def google_search(channel, nick, command)
        query = command.args.strip
        if (query.empty?)
          channel.message("#{nick.name}: please provide a search term.")
          return
        end
        LOGGER.debug("google request from #{nick.uhost}: #{query}")

        if (query.length > 79)
          query = query[0..79]
        end

        result = API::Google::CustomSearch::V1.search(query)

        if (!result.link.empty?)
          begin
            warnings  = API::WebOfTrust::V0_4::PublicLinkJSON2.get_rating(result.link)
          rescue
            warnings  = []
          end

          msg  = "#{Colors.gray}[#{Colors.green}google#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkgreen}#{nick.name}#{Colors.gray}]#{Colors.reset} "
          msg += result.irc_snippet
          msg += " #{Colors.gray}|#{Colors.reset} "
          if (warnings.any?)
            msg += result.link
            msg += " #{Colors.gray}[#{Colors.red}potentially #{warnings.join(', ')}#{Colors.gray}]#{Colors.reset}"
          else
            msg += URIUtils.shorten(result.link).to_s
          end
          channel.message(msg)
        else
          channel.message("#{nick.name}: No search results.")
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def google_image_search(channel, nick, command)
        query = command.args.strip
        if (query.empty?)
          channel.message("#{nick.name}: please provide a search term.")
          return
        end
        LOGGER.debug("google image search request from #{nick.uhost}: #{query}")

        if (query.length > 79)
          query = query[0..79]
        end

        result = API::Google::CustomSearch::V1.image_search(query)
        if (!result.link.empty?)
          begin
            warnings  = API::WebOfTrust::V0_4::PublicLinkJSON2.get_rating(result.link)
          rescue
            warnings  = []
          end

          msg  = "#{Colors.gray}[#{Colors.green}image search#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkgreen}#{nick.name}#{Colors.gray}]#{Colors.reset} "
          msg += result.title
          msg += " #{Colors.gray}|#{Colors.reset} "
          if (warnings.any?)
            msg += result.link
            msg += " #{Colors.gray}[#{Colors.red}potentially #{warnings.join(', ')}#{Colors.gray}]#{Colors.reset}"
          else
            msg += URIUtils.shorten(result.link).to_s
          end

          channel.message(msg)
        else
          channel.message("#{nick.name}: No image search results.")
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
