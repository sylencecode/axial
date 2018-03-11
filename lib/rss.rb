#!/usr/bin/env ruby

require 'nokogiri'
require 'feedjira'
require 'google/api/url_shortener/v1/url.rb'

Feedjira.logger.level = Logger::FATAL

module Axial
  module RSS
    # this needs some rework, doh
    class Feed
      attr_accessor :url, :last
      def initialize(url)
        @url = url
        @last = Time.now
      end
    end

    def start_rss()
      log "Starting RSS feed."
      Thread.new do
        begin
          feeds = [
            Axial::RSS::Feed.new('https://www.cnbc.com/id/100003114/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/100727362/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/15837362/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/15839069/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/10000664/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/19854910/device/rss/rss.html')
          ]
          while (true)
            sleep 30
          
            feeds.each do |feed|
              rss_content = Feedjira::Feed.fetch_and_parse(feed.url)
              feed_name = Nokogiri::HTML(rss_content.title).text.gsub(/\s+/, ' ').strip
              published = rss_content.entries.first.published
              title = Nokogiri::HTML(rss_content.entries.first.title).text.gsub(/\s+/, ' ').strip
              summary = Nokogiri::HTML(rss_content.entries.first.summary).text.gsub(/\s+/, ' ').strip
              article_url = rss_content.entries.first.url
            
              if (feed.last.nil?)
                feed.last = published - 1
              end
              
              if (published > feed.last)
                url_shortener = ::Google::API::URLShortener::V1::URL.new
                short_url = url_shortener.shorten(article_url)
                if (!short_url.empty?)
                  link = short_url
                else
                  link = article_url
                end
                msg =  "#{$irc_gray}[#{$irc_cyan}news update#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkcyan}#{feed_name}#{$irc_gray}]#{$irc_reset} "
                msg += title
                msg += " #{$irc_gray}|#{$irc_reset} "
                if (summary.length > 299)
                  msg += summary[0..296] + "..."
                else
                  msg += summary
                end
                msg += " #{$irc_gray}|#{$irc_reset} "
                msg += link
                send_channel('#lulz', msg)
                feed.last = published
              end
            end
          end
        rescue Exception => ex
          log "RSS error: #{ex.message}: #{ex.inspect}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end
    end
  end
end
