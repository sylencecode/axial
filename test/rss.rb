#!/usr/bin/env ruby

gem 'nokogiri'
gem 'feedjira'
require 'nokogiri'
require 'feedjira'

    class Feed
      attr_reader :url, :last, :name
      def initialize(url, name)
        @url = url
        @name = name
        @last = Time.now
      end
    end
#Feedjira.logger.level = Logger::FATAL

          feeds = [
#            Feed.new('http://rss.cnn.com/rss/cnn_latest.rss', 'cnn'),
#            Feed.new('https://www.cnbc.com/id/100003114/device/rss/rss.html', 'Fox News'),
#            Feed.new('https://www.theguardian.com/us/rss', 'The Guardian'),
#            Feed.new('https://threatpost.com/feed/', 'Tech News')
            Feed.new('https://www.wired.com/feed/category/security/latest/rss', 'wired - privacy')
          ]
          
          feeds.each do |feed|
            rss_content = Feedjira::Feed.fetch_and_parse(feed.url)
            rss_content.entries.each do |entry| #.select {|a| a.published > Time.now - 14400}.each do |entry|
              published = entry.published
              puts published
              summary = Nokogiri::HTML(entry.summary).text.gsub(/\s+/, ' ').strip
                title = Nokogiri::HTML(entry.title).text.gsub(/\s+/, ' ').strip
              article_url = entry.url
              puts feed.name
              puts title 
              puts summary.inspect
              puts article_url
            end
          end
