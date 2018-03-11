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
      # TODO: change location of this class/model
      # TODO: move the list of feeds to the database and allow adding/removing via command?
      Thread.new do
        begin
          feeds = [
            Axial::RSS::Feed.new('https://www.cnbc.com/id/100003114/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/100727362/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/15837362/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/15839069/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/10000664/device/rss/rss.html'),
            Axial::RSS::Feed.new('https://www.cnbc.com/id/19854910/device/rss/rss.html'),
            Axial::RSS::Feed.new('http://rss.cnn.com/rss/cnn_latest.rss')
          ]
          while (true)
            sleep 60
          
            feeds.each do |feed|
              old_last = feed.last
              rss_content = Feedjira::Feed.fetch_and_parse(feed.url)
              feed.last = Time.now
              feed_name = Nokogiri::HTML(rss_content.title).text.gsub(/\s+/, ' ').strip

              rss_content.entries.select {|tmp_entry| tmp_entry.published > old_last}.each do |entry|
                published = entry.published
                title = Nokogiri::HTML(entry.title).text.gsub(/\s+/, ' ').strip
                summary = Nokogiri::HTML(entry.summary).text.gsub(/\s+/, ' ').strip
                article_url = entry.url

                url_shortener = ::Google::API::URLShortener::V1::URL.new
                short_url = url_shortener.shorten(article_url)
                if (!short_url.empty?)
                  link = short_url
                else
                  link = article_url
                end
                msg =  "#{$irc_gray}[#{$irc_cyan}news#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkcyan}#{feed_name}#{$irc_gray}]#{$irc_reset} "
                msg += title
                if (!summary.empty?)
                  msg += " #{$irc_gray}|#{$irc_reset} "
                  if (summary.length > 299)
                    msg += summary[0..296] + "..."
                  else
                    msg += summary
                  end
                end
                msg += " #{$irc_gray}|#{$irc_reset} "
                msg += link
                # TODO: fix this when you have a channels collection
                #    can you privmsg #chan1,#chan2 instead of one each?
                send_channel('#lulz', msg)
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
