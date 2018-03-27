require 'axial/addon'
require 'axial/models/user'
require 'axial/models/mask'

module Axial
  module Addons
    class Seen < Axial::Addon
      def initialize(bot)
        super

        @name    = 'last seen'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?seen', :seen
        on_join             :update_seen_join
        on_part             :update_seen_part
        on_quit             :update_seen_quit
        on_kick             :update_seen_kick
        throttle            2
      end

      def seen(channel, nick, command)
        who = command.args.strip
        if (who.empty?)
          channel.message("#{nick.name}: try ?seen <nick> instead of whatever you just did.")
          return
        end
        subject_model = Models::User[name: who.downcase]
        if (subject_model.nil?)
          channel.message("#{nick.name}: I don't recall seeing #{who}.")
          return
        end
        seen_at = Axial::TimeSpan.new(subject_model.seen.last, Time.now)
        LOGGER.debug("reported seeing #{subject_model.pretty_name} to #{nick.uhost}")
        msg = "#{nick.name}: #{who} was last seen #{subject_model.seen.status} #{seen_at.approximate_to_s} ago."
        channel.message(msg)
      rescue StandardError => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_kick(channel, kicker_nick, kicked_nick, reason)
        user = Models::Mask.get_user_from_mask(kicked_nick.uhost)
        if (!user.nil?)
          status = "getting kicked from #{channel.name} by #{kicker_nick.name} (#{reason})"
          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_join(channel, nick)
        user = Models::Mask.get_user_from_mask(nick.uhost)
        if (!user.nil?)
          status = "joining #{channel.name}"
          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_part(channel, nick, reason)
        user = Models::Mask.get_user_from_mask(nick.uhost)
        if (!user.nil?)
          if (reason.nil? || reason.empty?)
            status = "leaving #{channel.name}")
          else
            status = "leaving #{channel.name} (#{reason})"
          end
          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_quit(nick, reason)
        user = Models::Mask.get_user_from_mask(nick.uhost)
        if (!user.nil?)
          if (reason.nil? || reason.empty?)
            status = "quitting IRC"
          else
            status = "quitting IRC (#{reason})"
          end

          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
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
