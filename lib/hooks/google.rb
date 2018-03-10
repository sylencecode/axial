require_relative '../google/api/custom_search_v1.rb'

module Axial
  module Hooks
    module Google
      def handle_google(nick, channel, query)
        begin
          if (query.length > 79)
            query = query[0..79]
          end
          search = ::Google::API::CustomSearchV1.new
          result = search.search(query)
          if (!result.irc_snippet.empty?)
            url_shortener = ::Google::API::URLShortener::V1::URL.new
            short_url = url_shortener.shorten(result.link)
            if (!short_url.empty?)
              link = short_url
            else
              link = result.link
            end
            msg  = "#{$irc_gray}[#{$irc_green}google#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkgreen}#{nick}#{$irc_gray}]#{$irc_reset} "
            msg += result.irc_snippet
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += link
            send_channel(channel, msg)
          else
            send_channel(channel, "#{nick}: No search results.")
          end
        rescue Exception => ex
          log "Google CustomSearchV1 error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end
    end
  end
end
