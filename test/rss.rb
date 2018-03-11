#!/usr/bin/env ruby

require 'nokogiri'
require 'feedjira'

    class Feed
      attr_accessor :url, :last
      def initialize(url)
        @url = url
        @last = Time.now
      end
    end
Feedjira.logger.level = Logger::FATAL

          feeds = [
            Feed.new('http://rss.cnn.com/rss/cnn_latest.rss')
          ]
          
          feeds.each do |feed|
            rss_content = Feedjira::Feed.fetch_and_parse(feed.url)
            rss_content.entries.select {|a| a.published > Time.now - 3600}.each do |entry|
              feed_name = Nokogiri::HTML(rss_content.title).text.gsub(/\s+/, ' ').strip
              published = entry.published
              title = Nokogiri::HTML(entry.title).text.gsub(/\s+/, ' ').strip
              summary = Nokogiri::HTML(entry.summary).text.gsub(/\s+/, ' ').strip
              article_url = entry.url
              puts feed_name
              puts published
              puts title
              puts summary
              puts article_url
            end
          end
