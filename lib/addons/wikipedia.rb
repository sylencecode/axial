require 'wikipedia/api/w.rb'
require 'google/api/url_shortener/v1/url.rb'

module Axial
  module Addons
    class Wikipedia < Axial::Addon

      def initialize()
        super

        @name    = 'wikipedia search'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?w',         :handle_wikipedia
        on_channel '?wiki',      :handle_wikipedia
        on_channel '?wikipedia', :handle_wikipedia
      end

      def handle_wikipedia(channel, nick, command)
        query = command.args.strip
        if (query.empty?)
          channel.message("#{nick.name}: Please provide a topic for a wikipedia search.")
          return
        end
        log "wikipedia request from #{nick.uhost}: #{query}"
        begin
          if (query.length > 79)
            query = query[0..79]
          end
          search = ::Wikipedia::API::W.new
          article = search.search(query)
          if (article.found)
            url_shortener = ::Google::API::URLShortener::V1::URL.new
            short_url = url_shortener.shorten(article.url)
            if (!short_url.empty?)
              link = short_url
            else
              link = article.url
            end
            msg =  "#{$irc_gray}[#{$irc_red}wikipedia#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkred}#{nick.name}#{$irc_gray}]#{$irc_reset} "
            msg += article.irc_extract
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += link
            channel.message(msg)
          else
            channel.message("#{nick.name}: No results, or the wikipedia API sucks. Try ?g instead to perform a google search.")
          end
        rescue Exception => ex
          channel.message("Wikipedia error: #{ex.class}: #{ex.message}")
          log "Wikipedia error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end
    end
  end
end
