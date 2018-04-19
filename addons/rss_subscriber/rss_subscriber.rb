gem 'nokogiri'
gem 'feedjira'
require 'feedjira'
require 'nokogiri'
require 'axial/uri_utils.rb'
require 'axial/addon'
require 'axial/models/user'
require 'axial/models/rss_feed'
require 'axial/timespan'

Feedjira.logger.level = Logger::FATAL

module Axial
  module Addons
    class RSSSubscriber < Axial::Addon
      def initialize(bot)
        super

        @name                 = 'rss feed ingest'
        @author               = 'sylence <sylence@sylence.org>'
        @version              = '1.1.0'

        @ingest_timer         = nil

        @rss_timeout          = 5

        # change to [] to send to all channels
        @restrict_to_channels = %w[ #lulz ]

        on_channel   'feed',  :handle_rss_command
        on_channel   'news',  :handle_rss_command
        on_channel   'rss',   :handle_rss_command
        on_startup            :start_ingest_timer
        on_reload             :start_ingest_timer

        throttle              2
      end

      def stop_ingest_timer()
        LOGGER.debug('stopping ingest timer')
        timer.delete(@ingest_timer)
      end

      def start_ingest_timer()
        LOGGER.debug('starting ingest timer')
        DB_CONNECTION[:rss_feeds].update(last_ingest: Time.now)
        timer.get_from_callback_method(:ingest).each do |tmp_timer|
          LOGGER.debug("warning - removing errant ingest timer #{tmp_timer.callback_method}")
          timer.delete(tmp_timer)
        end
        @ingest_timer = timer.every_minute(self, :ingest)
      end

      def process_rss_entries(feed, rss_content)
        ingested = 0
        recent_entries = rss_content.entries.select { |tmp_entry| tmp_entry.published > feed.last_ingest }
        recent_entries.each do |entry|
          published = entry.published
          if (published > Time.now) # some idiots post articles dated for a future time
            next
          end

          msg = get_entry_message(feed, entry)

          channel_list.all_channels.each do |channel|
            if (@restrict_to_channels.any? && !@restrict_to_channels.include?(channel.name.downcase))
              next
            end

            channel.message(msg)
          end
          ingested += 1
        end
        return ingested
      end

      def rss_safe_fetch(feed)
        begin
          rss_content = nil
          Timeout.timeout(@rss_timeout) do
            rss_content = Feedjira::Feed.fetch_and_parse(feed.pretty_url)
          end
        rescue Feedjira::NoParserAvailable
          LOGGER.warn("#{self.class}: feed '#{feed.pretty_name}' did not present valid XML to feedjira. skipping.")
        rescue Timeout::Error, OpenSSL::SSL::SSLError => ex
          LOGGER.warn("#{self.class}: error connecting to #{feed.pretty_url}: #{ex.class}: #{ex.message}")
        end
        return rss_content
      end

      def ingest()
        LOGGER.debug('RSS: running feed check')
        Models::RssFeed.where(enabled: true).each do |feed|
          rss_content = rss_safe_fetch(feed)
          if (rss_content.nil?)
            next
          end

          ingested = process_rss_entries(feed, rss_content)
          if (ingested.zero?)
            next
          end

          # if any valid articles were found, update the last ingest timestamp
          LOGGER.debug("Resetting last_ingest time of #{feed.pretty_name} from #{feed.last_ingest} to #{Time.now}")
          feed.update(ingest_count: feed.ingest_count + ingested)
          feed.update(last_ingest: Time.now)
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def get_entry_message(feed, entry) # rubocop:disable Metrics/AbcSize
        title = Nokogiri::HTML(entry.title).text.gsub(/\s+/, ' ').strip
        summary = Nokogiri::HTML(entry.summary).text.gsub(/\s+/, ' ').strip

        text =  "#{Colors.gray}[#{Colors.cyan}news#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkcyan}#{feed.pretty_name}#{Colors.gray}]#{Colors.reset} "

        text += title
        text += " #{Colors.gray}|#{Colors.reset} "

        summary = (summary.length < 300) ? summary : text += summary[0..296] + '...'
        text += summary
        text += " #{Colors.gray}|#{Colors.reset} "

        article_url = URIUtils.shorten(entry.url)
        text += article_url.to_s
        return text
      end

      def send_help(channel, nick)
        channel.message("#{nick.name}: try ?rss add <name> = <feed url>, ?rss delete <name>, ?rss list, ?rss enable, or ?rss disable.")
      end

      def get_feed_hash(channel, nick, command, feed_args)
        feed_hash = {}
        if (feed_args.strip !~ /(.*)=(.*)/)
          channel.message("#{nick.name}: usage: #{command.command} add <name> = <url>")
          return
        end

        feed_array = feed_args.split('=')
        feed_name = feed_array.shift.strip
        feed_url = feed_array.join('=').strip

        if (feed_url.empty?)
          channel.message("#{nick.name}: usage: #{command.command} add <name> = <url>")
        elsif (feed_name.length > 32)
          channel.message("#{nick.name}: your feed name is too long (<= 32 characters).")
        elsif (feed_url.length > 128)
          channel.message("#{nick.name}: your feed url is too long (<= 128 characters).")
        else
          feed_hash = { name: feed_name, url: feed_url }
        end

        return feed_hash
      end

      def add_feed(channel, nick, user_model, command, args)
        feed_hash = get_feed_hash(channel, nick, command, args)
        if (feed_hash.empty?)
          return
        end

        feed_url = feed_hash[:url]
        feed_name = feed_hash[:name]
        parsed_urls = URIUtils.extract(feed_url)
        if (parsed_urls.empty?)
          channel.message("#{nick.name}: '#{feed_url}' is not a valid URI. (requires http/https url)")
          return
        end
        parsed_url = parsed_urls.first

        rss_content = rss_safe_fetch(parsed_url)
        if (rss_content.nil?)
          channel.message("#{nick.name}: cannot parse data from '#{feed_url}' - is it a valid RSS feed?")
          return
        end

        Models::RssFeed.upsert(feed_name, parsed_url, user_model)
        LOGGER.info("RSS: #{nick.uhost} added #{feed_name} -> #{parsed_url}")
        channel.message("#{nick.name}: ok, now following articles from feed '#{feed_name}'.")
      end

      def get_feed_string(feed)
        last    = TimeSpan.new(Time.now, feed.last_ingest)
        enabled = (feed.enabled) ? 'enabled' : 'disabled'

        msg  = "#{Colors.gray}[#{Colors.reset} #{feed.pretty_name} #{Colors.gray}|#{Colors.reset} "
        msg += "#{feed.pretty_url} #{Colors.gray}|#{Colors.reset} "
        msg += "added: #{feed.added.strftime('%m/%d/%Y')} by #{feed.user.pretty_name_with_color} #{Colors.gray}|#{Colors.reset} "
        msg += "ingested: #{feed.ingest_count} articles #{Colors.gray}|#{Colors.reset} "
        msg += "last: #{last.short_to_s} ago #{Colors.gray}|#{Colors.reset} "
        msg += "#{enabled} #{Colors.gray}]#{Colors.reset}"
        return msg
      end

      def list_feeds(channel, nick)
        feeds = Models::RssFeed.all
        if (feeds.any?)
          LOGGER.debug("RSS: #{nick.uhost} listed feeds")
          channel.message('rss feeds:')
          feeds.each do |feed|
            msg = get_feed_string(feed)
            channel.message(msg)
          end
        else
          channel.message('no feeds.')
        end
      end

      def disable_feed(channel, nick, feed_name)
        feed_model = Models::RssFeed[name: feed_name.downcase]
        if (feed_model.nil?)
          channel.message("#{nick.name}: no feeds named '#{feed_name}'.")
        else
          feed_model.update(enabled: false)
          LOGGER.info("RSS: #{nick.uhost} disabled #{feed_name}")
          channel.message("#{nick.name}: ok, '#{feed_name}' disabled.")
        end
      end

      def enable_feed(channel, nick, feed_name)
        feed_model = Models::RssFeed[name: feed_name.downcase]
        if (feed_model.nil?)
          channel.message("#{nick.name}: no feeds named '#{feed_name}'.")
        else
          feed_model.update(enabled: true)
          LOGGER.info("RSS: #{nick.uhost} enabled #{feed_name}")
          channel.message("#{nick.name}: ok, '#{feed_name}' enabled.")
        end
      end

      def delete_feed(channel, nick, feed_name)
        feed_model = Models::RssFeed[name: feed_name.downcase]
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

      def handle_rss_command(channel, nick, command) # rubocop:disable Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/AbcSize
        user_model = Models::User.get_from_nick_object(nick)
        if (user_model.nil? || !user_model.role.director?)
          return
        end

        if (command.first_argument.empty?)
          send_help(channel, nick)
          return
        end

        case (command.args.strip)
          when /^add\s+(\S+.*)/i
            add_feed(channel, nick, user_model, command, Regexp.last_match[1].strip)
          when /^delete\s+(\S+.*)/i, /^remove\s+(\S+.*)/i
            delete_feed(channel, nick, Regexp.last_match[1].strip)
          when /^list$/i, /^list\s+/i
            list_feeds(channel, nick)
          when /^disable\s+(\S+.*)/i
            disable_feed(channel, nick, Regexp.last_match[1].strip)
          when /^enable\s+(\S+.*)/i
            enable_feed(channel, nick, Regexp.last_match[1].strip)
          when /^stop$/i, /^stop\s+/i
            stop_ingest(channel, nick)
          when /^start$/i, /^start\s+/i
            start_ingest(channel, nick)
          else
            send_help(channel, nick)
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping RSS ingest before addons are reloaded")
        stop_ingest_timer
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}", __FILE__, __LINE__)
        end
      end
    end
  end
end
