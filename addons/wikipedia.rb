require 'axial/addon'
require 'axial/api/wikipedia/w'
require 'axial/uri_utils'

module Axial
  module Addons
    class Wikipedia < Axial::Addon

      def initialize()
        super

        @name    = 'wikipedia search'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?wiki',      :handle_wikipedia
        on_channel '?wikipedia', :handle_wikipedia
      end

      def handle_wikipedia(channel, nick, command)
        query = command.args.strip
        if (query.empty?)
          channel.message("#{nick.name}: please provide a search term.")
          return
        end
        LOGGER.debug("wikipedia request from #{nick.uhost}: #{query}")
        begin
          if (query.length > 79)
            query = query[0..79]
          end
          article = API::Wikipedia::W.search(query)
          if (article.found)
            link = URIUtils.shorten(article.url)
            msg =  "#{Colors.gray}[#{Colors.red}wikipedia#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkred}#{nick.name}#{Colors.gray}]#{Colors.reset} "
            msg += article.irc_extract
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += link.to_s
            channel.message(msg)
          else
            channel.message("#{nick.name}: no results, or the wikipedia API sucks. try ?g instead to perform a google search.")
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
end
