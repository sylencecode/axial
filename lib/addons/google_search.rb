require 'uri_utils.rb'
require 'api/google/custom_search/v1.rb'

module Axial
  module Addons
    class GoogleSearch < Axial::Addon
      def initialize()
        super

        @name    = 'google custom search'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?gis',          :google_image_search
        on_channel '?image',        :google_image_search
        on_channel '?imagesearch',  :google_image_search
        on_channel '?google',       :google_search
        on_channel '?g',            :google_search
      end
      
      def google_search(channel, nick, command)
        query = command.args.strip
        if (query.empty?)
          channel.message("#{nick.name}: please provide a search term.")
          return
        end
        log "google request from #{nick.uhost}: #{query}"

        if (query.length > 79)
          query = query[0..79]
        end

        result = API::Google::CustomSearch::V1.search(query)
        if (!result.link.empty?)
          short_url = URIUtils.shorten(result.link)
          if (short_url.nil?)
            link = result.link
          else
            link = short_url.to_s
          end
          msg  = "#{$irc_gray}[#{$irc_green}google#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkgreen}#{nick.name}#{$irc_gray}]#{$irc_reset} "
          msg += result.irc_snippet
          msg += " #{$irc_gray}|#{$irc_reset} "
          msg += link
          channel.message(msg)
        else
          channel.message("#{nick.name}: No search results.")
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        log "#{self.class} error: #{ex.class}: #{ex.message}"
        ex.backtrace.each do |i|
          log i
        end
      end

      def google_image_search(channel, nick, command)
        query = command.args.strip
        if (query.empty?)
          channel.message("#{nick.name}: please provide a search term.")
          return
        end
        log "gis request from #{nick.uhost}: #{query}"

        if (query.length > 79)
          query = query[0..79]
        end

        result = API::Google::CustomSearch::V1.image_search(query)
        if (!result.link.empty?)
          short_url = URIUtils.shorten(result.link)
          if (short_url.nil?)
            link = result.link
          else
            link = short_url.to_s
          end
          msg  = "#{$irc_gray}[#{$irc_green}gis#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkgreen}#{nick.name}#{$irc_gray}]#{$irc_reset} "
          msg += result.title
          msg += " #{$irc_gray}|#{$irc_reset} "
          msg += link
          channel.message(msg)
        else
          channel.message("#{nick.name}: No image search results.")
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
