#!/usr/bin/env ruby

require 'nokogiri'
require 'feedjira'
require 'uri_utils.rb'
require 'models/nick.rb'
require 'models/rss_feed.rb'
require 'google/api/url_shortener/v1/url.rb'

Feedjira.logger.level = Logger::FATAL

module Axial
  module Addons
    class RSSSubscriber < Axial::Addon
      def initialize()
        super

        @name    = 'rss feed ingest'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?feed', :handle_rss_command
        on_channel '?news', :handle_rss_command
        on_channel '?rss',  :handle_rss_command

        @ingest_thread = start_ingest_thread('#lulz')
      end

      def stop_ingest_thread()
        @ingest_thread.kill
      end

      def start_ingest_thread(channel_name)
        DB[:rss_feeds].update(last_ingest: Time.now)
        @thread = Thread.new do
          begin
            sleep 15
            while (true)
              Models::RSSFeed.where(enabled: true).each do |feed|
                rss_content = Feedjira::Feed.fetch_and_parse(feed.pretty_url)
                rss_content.entries.select {|tmp_entry| tmp_entry.published > feed.last_ingest}.each do |entry|
                  if (published > Time.now)
                    next
                  end
                  published = entry.published
                  feed.update(last_ingest: published)
                  title = Nokogiri::HTML(entry.title).text.gsub(/\s+/, ' ').strip
                  summary = Nokogiri::HTML(entry.summary).text.gsub(/\s+/, ' ').strip
                  article_url = entry.url
                  feed.update(ingest_count: feed.ingest_count + 1)
  
                  url_shortener = ::Google::API::URLShortener::V1::URL.new
                  short_url = url_shortener.shorten(article_url)
                  if (!short_url.empty?)
                    link = short_url
                  else
                    link = article_url
                  end
                  msg =  "#{$irc_gray}[#{$irc_cyan}news#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkcyan}#{feed.pretty_name}#{$irc_gray}]#{$irc_reset} "
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
                  begin
                    @irc.send_channel(channel_name, msg)
                  rescue Exception => ex
                    @irc.send_channel(channel_name, "RSS error: #{ex.message}: #{ex.inspect}")
                    log "RSS error: #{ex.message}: #{ex.inspect}"
                    ex.backtrace.each do |i|
                      log i
                    end
                  end
                end
              end
              sleep 15
            end
          rescue Exception => ex
            send_channel(channel, "RSS error: #{ex.message}: #{ex.inspect}")
            log "RSS error: #{ex.message}: #{ex.inspect}"
            ex.backtrace.each do |i|
              log i
            end
          end
        end
      end

      def send_help(channel, nick)
        channel.message("#{nick.name}: try ?rss add <name> = <feed url>, ?rss delete <name>, ?rss list, ?rss enable, or ?rss disable.")
      end

      def add_feed(channel, nick, nick_model, args)
        if (args.strip =~ /(.*)=(.*)/)
          feed_name = Regexp.last_match[1].strip
          feed_url = Regexp.last_match[2].strip
          if (feed_name.empty? || feed_url.empty?)
            channel.message("#{nick.name}: try ?rss add <name> = <url> instead of whatever you just did.")
            return
          end
        else
          channel.message("#{nick.name}: try ?rss add <name> = <url> instead of whatever you just did.")
          return
        end
        
        if (feed_name.length > 32)
          channel.message("#{nick.name}: your feed name is too long (<= 32 characters).")
          return
        elsif (feed_url.length > 128)
          channel.message("#{nick.name}: your feed url explanation is too long (<= 128 characters).")
          return
        end

        parsed_urls = Axial::URIUtils.extract(feed_url)
        if (parsed_urls.count == 0)
          channel.message("#{nick.name}: '#{feed_url}' is not a valid URI. (http|https)")
          return
        end
        parsed_url = parsed_urls.first

        begin
          rss_content = Feedjira::Feed.fetch_and_parse(parsed_url)
          Models::RSSFeed.upsert(feed_name, parsed_url, nick_model)
          log "RSS: #{nick.uhost} added #{feed_name} -> #{parsed_url}"
          channel.message("#{nick.name}: ok, following articles from '#{feed_name}'.")
        rescue Feedjira::NoParserAvailable
          channel.message("#{nick.name}: '#{feed_url}' can't be parsed. is it a valid RSS feed?")
        end
      end

      def list_feeds(channel, nick)
        feeds = Models::RSSFeed.all
        if (feeds.count > 0)
          log "RSS: #{nick.uhost} listed feeds"
          channel.message("rss feeds:")
          feeds.each do |feed|
            msg  = "#{$irc_gray}[#{$irc_reset} "
            msg += feed.pretty_name
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += feed.pretty_url
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += "added on #{feed.added.strftime("%m/%d/%Y")} by #{feed.nick.pretty_nick}"
            msg += " #{$irc_gray}|#{$irc_reset} "
            msg += "#{feed.ingest_count} ingested"
            msg += " #{$irc_gray}|#{$irc_reset} "
            last = TimeSpan.new(Time.now, feed.last_ingest)
            msg += "last: #{last.short_to_s} ago"
            msg += " #{$irc_gray}|#{$irc_reset} "
            if (feed.enabled)
              msg += "enabled"
            else
              msg += "disabled"
            end
            msg += " #{$irc_gray}]#{$irc_reset}"
            channel.message(msg)
          end
        else
          channel.message("no feeds.")
        end
      end

      def disable_feed(channel, nick, feed_name)
        feed_model = Models::RSSFeed[name: feed_name.downcase]
        if (feed_model.nil?)
          channel.message("#{nick.name}: no feeds named '#{feed_name}'.")
        else
          feed_model.update(enabled: false)
          log "RSS: #{nick.uhost} disabled #{feed_name}"
          channel.message("#{nick.name}: ok, '#{feed_name}' disabled.")
        end
      end

      def enable_feed(channel, nick, feed_name)
        feed_model = Models::RSSFeed[name: feed_name.downcase]
        if (feed_model.nil?)
          channel.message("#{nick.name}: no feeds named '#{feed_name}'.")
        else
          feed_model.update(enabled: true)
          log "RSS: #{nick.uhost} enabled #{feed_name}"
          channel.message("#{nick.name}: ok, '#{feed_name}' enabled.")
        end
      end

      def delete_feed(channel, nick, feed_name)
        feed_model = Models::RSSFeed[name: feed_name.downcase]
        if (feed_model.nil?)
          channel.message("#{nick.name}: no feeds named '#{feed_name}'.")
        else
          feed_model.delete
          log "RSS: #{nick.uhost} deleted #{feed_name}"
          channel.message("#{nick.name}: ok, '#{feed_name}' deleted.")
        end
      end

      def stop_ingest(channel, nick)
        if (@ingest_thread.alive? || @ingest_thread.stop?)
          channel.message("#{nick.name}: ok, stopping feed ingest.")
          stop_ingest_thread
          log "RSS: #{nick.uhost} stopped ingest"
        else
          channel.message("#{nick.name}: not currently ingesting feeds.")
          return
        end
      end

      def start_ingest(channel, nick)
        if (@ingest_thread.alive?)
          channel.message("#{nick.name}: already ingesting feeds.")
          return
        else
          channel.message("#{nick.name}: ok, starting feed ingest.")
          start_ingest_thread
          log "RSS: #{nick.uhost} started ingest"
        end
      end

      def handle_rss_command(channel, nick, command)
        begin
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          if (command.args.strip.empty?)
            send_help(channel, nick)
            return
          end

          case (command.args.strip)
            when /^add\s+(\S+.*)/i
              add_feed(channel, nick, nick_model, Regexp.last_match[1].strip)
              return
            when /^delete\s+(\S+.*)/i, /^remove\s+(\S+.*)/i
              delete_feed(channel, nick, Regexp.last_match[1].strip)
              return
            when /^list$/i, /^list\s+/i
              list_feeds(channel, nick)
              return
            when /^disable\s+(\S+.*)/i
              disable_feed(channel, nick, Regexp.last_match[1].strip)
              return
            when /^enable\s+(\S+.*)/i
              enable_feed(channel, nick, Regexp.last_match[1].strip)
              return
            when /^stop$/i, /^stop\s+/i
              stop_ingest(channel, nick)
              return
            when /^start$/i, /^start\s+/i
              start_ingest(channel, nick)
              return
          else
            send_help(channel, nick)
            return
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
end
