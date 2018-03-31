gem 'nokogiri'
gem 'feedjira'
require 'feedjira'
require 'nokogiri'
require 'axial/uri_utils.rb'
require 'axial/addon'
require 'axial/models/user'
require 'axial/models/rss_feed'

Feedjira.logger.level = Logger::FATAL

module Axial
  module Addons
    class RSSSubscriber < Axial::Addon
      def initialize(bot)
        super

        @name    = 'rss feed ingest'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        @ingest_timer         = nil

        on_channel  '?feed',  :handle_rss_command
        on_channel  '?news',  :handle_rss_command
        on_channel  '?rss',   :handle_rss_command
        on_startup            :start_ingest_timer
        on_reload             :start_ingest_timer
      end

      def stop_ingest_timer()
        LOGGER.debug("stopping ingest timer")
        timer.delete(@ingest_timer)
      end

      def start_ingest_timer()
        LOGGER.debug("starting ingest timer")
        DB_CONNECTION[:rss_feeds].update(last_ingest: Time.now)
        @ingest_timer = timer.every_minute(self, :ingest)
      end

      def ingest()
        LOGGER.debug("RSS: running feed check")
        Models::RSSFeed.where(enabled: true).each do |feed|
          ingested = 0
          begin
            rss_content = Feedjira::Feed.fetch_and_parse(feed.pretty_url)
          rescue Feedjira::NoParserAvailable
            LOGGER.warn("RSS consumer: feed '#{feed.pretty_name}' did not present valid XML to feedjira. skipping.")
            next
          end
          recent_entries = rss_content.entries.select { |tmp_entry| tmp_entry.published > feed.last_ingest }
          recent_entries.each do |entry|
            published = entry.published
            if (published > Time.now) # some idiots post articles dated for a future time
              next
            end

            title = Nokogiri::HTML(entry.title).text.gsub(/\s+/, ' ').strip
            summary = Nokogiri::HTML(entry.summary).text.gsub(/\s+/, ' ').strip
            article_url = entry.url

            link = URIUtils.shorten(article_url)

            text =  "#{Colors.gray}[#{Colors.blue}news#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkblue}#{feed.pretty_name}#{Colors.gray}]#{Colors.reset} "
            text += title

            if (!summary.empty?)
              text += " #{Colors.gray}|#{Colors.reset} "
              if (summary.length > 299)
                text += summary[0..296] + "..."
              else
                text += summary
              end
            end

            text += " #{Colors.gray}|#{Colors.reset} "
            text += link.to_s

            channel_list.all_channels.each do |channel|
              channel.message(text)
            end
            ingested = ingested + 1
          end

          if (ingested > 0) # if any valid articles were found, update the last ingest timestamp
            LOGGER.debug("Resetting last_ingest time of #{feed.pretty_name} from #{feed.last_ingest} to #{Time.now}")
            feed.update(ingest_count: feed.ingest_count + ingested)
            feed.update(last_ingest: Time.now)
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def send_help(channel, nick)
        channel.message("#{nick.name}: try ?rss add <name> = <feed url>, ?rss delete <name>, ?rss list, ?rss enable, or ?rss disable.")
      end

      def add_feed(channel, nick, user_model, args)
        if (args.strip =~ /(.*)=(.*)/)
          feed_array = args.split('=')
          feed_name = feed_array.shift.strip
          feed_url = feed_array.join('=').strip
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

        parsed_urls = URIUtilsUtils.extract(feed_url)
        if (parsed_urls.count == 0)
          channel.message("#{nick.name}: '#{feed_url}' is not a valid URI. (http|https)")
          return
        end
        parsed_url = parsed_urls.first

        begin
          rss_content = Feedjira::Feed.fetch_and_parse(parsed_url)
          Models::RSSFeed.upsert(feed_name, parsed_url, user_model)
          LOGGER.info("RSS: #{nick.uhost} added #{feed_name} -> #{parsed_url}")
          channel.message("#{nick.name}: ok, following articles from '#{feed_name}'.")
        rescue Feedjira::NoParserAvailable
          channel.message("#{nick.name}: '#{feed_url}' can't be parsed. is it a valid RSS feed?")
        end
      end

      def list_feeds(channel, nick)
        feeds = Models::RSSFeed.all
        if (feeds.count > 0)
          LOGGER.debug("RSS: #{nick.uhost} listed feeds")
          channel.message("rss feeds:")
          feeds.each do |feed|
            msg  = "#{Colors.gray}[#{Colors.reset} "
            msg += feed.pretty_name
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += feed.pretty_url
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += "added on #{feed.added.strftime("%m/%d/%Y")} by #{feed.user.pretty_name}"
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += "#{feed.ingest_count} ingested"
            msg += " #{Colors.gray}|#{Colors.reset} "
            last = TimeSpan.new(Time.now, feed.last_ingest)
            msg += "last: #{last.short_to_s} ago"
            msg += " #{Colors.gray}|#{Colors.reset} "
            if (feed.enabled)
              msg += "enabled"
            else
              msg += "disabled"
            end
            msg += " #{Colors.gray}]#{Colors.reset}"
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
          LOGGER.info("RSS: #{nick.uhost} disabled #{feed_name}")
          channel.message("#{nick.name}: ok, '#{feed_name}' disabled.")
        end
      end

      def enable_feed(channel, nick, feed_name)
        feed_model = Models::RSSFeed[name: feed_name.downcase]
        if (feed_model.nil?)
          channel.message("#{nick.name}: no feeds named '#{feed_name}'.")
        else
          feed_model.update(enabled: true)
          LOGGER.info("RSS: #{nick.uhost} enabled #{feed_name}")
          channel.message("#{nick.name}: ok, '#{feed_name}' enabled.")
        end
      end

      def delete_feed(channel, nick, feed_name)
        feed_model = Models::RSSFeed[name: feed_name.downcase]
        if (feed_model.nil?)
          channel.message("#{nick.name}: no feeds named '#{feed_name}'.")
        else
          feed_model.delete
          LOGGER.info("RSS: #{nick.uhost} deleted #{feed_name}")
          channel.message("#{nick.name}: ok, '#{feed_name}' deleted.")
        end
      end

      def stop_ingest(channel, nick)
        if (!@ingest_timer.nil? && timer.include?(@ingest_timer))
          channel.message("#{nick.name}: ok, stopping feed ingest.")
          stop_ingest_timer
          LOGGER.info("RSS: #{nick.uhost} stopped ingest")
        else
          channel.message("#{nick.name}: not currently ingesting feeds.")
          return
        end
      end

      def start_ingest(channel, nick)
        if (!@ingest_timer.nil? && timer.include?(@ingest_timer))
          channel.message("#{nick.name}: already ingesting feeds.")
          return
        else
          channel.message("#{nick.name}: ok, starting feed ingest.")
          start_ingest_timer
          LOGGER.info("RSS: #{nick.uhost} started ingest")
        end
      end

      def handle_rss_command(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          if (command.args.strip.empty?)
            send_help(channel, nick)
            return
          end

          case (command.args.strip)
            when /^add\s+(\S+.*)/i
              add_feed(channel, nick, user_model, Regexp.last_match[1].strip)
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
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping RSS ingest before addons are reloaded")
        stop_ingest_timer
      end
    end
  end
end
