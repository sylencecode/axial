require 'axial/addon'
require 'axial/api/wikipedia/w'
require 'axial/uri_utils'

module Axial
  module Addons
    class Wikipedia < Axial::Addon
      def initialize(bot)
        super

        @name                           = 'wikipedia search'
        @author                         = 'sylence <sylence@sylence.org>'
        @version                        = '1.1.0'

        throttle                        5

        on_channel  'wiki|wikipedia',   :fetch_wikipedia_article
      end

      def fetch_wikipedia_article(channel, nick, command)
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
          output_article(channel, nick, article)
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def output_article(channel, nick, article)
        if (article.found)
          link = URIUtils.shorten(article.url)
          msg = Color.red_prefix('wikipedia', nick.name)
          msg += article.irc_extract
          msg += " #{Colors.gray}|#{Colors.reset} "
          msg += link.to_s
          channel.message(msg)
        else
          channel.message("#{nick.name}: no results, or the wikipedia API sucks. try ?g instead to perform a google search.")
        end
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
