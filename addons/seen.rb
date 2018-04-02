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
        @version = '1.1.0'
  
        on_channel      'seen',   :seen
        on_channel 'lastspoke',   :seen
        on_channel      'last',   :seen

        on_channel_any            :update_last_spoke
        on_join                   :update_seen_join
        on_part                   :update_seen_part
        on_quit                   :update_seen_quit
        on_kick                   :update_seen_kick
        throttle                  2
      end

      def update_last_spoke(channel, nick, text)
        nick.last_spoke = { time: Time.now, text: text }
      end

      def seen(channel, nick, command)
        subject_name = command.args.strip
        if (subject_name.empty?)
          channel.message("#{nick.name}: try #{command.command} <nick> instead of whatever you just did.")
          return
        elsif (subject_name.casecmp(nick.name.downcase).zero?)
          channel.message("#{nick.name}: are you still trying to find yourself?")
          return
        end

        who = channel.nick_list.get_silent(subject_name)
        if (who.nil?)
          subject_model = Models::User[name: subject_name.downcase]
          if (subject_model.nil?)
            channel.message("#{nick.name}: I don't know anything about #{subject_name}.")
          else
            seen_at = TimeSpan.new(subject_model.seen.last, Time.now)
            if (subject_model.seen.status =~ /^for the first time/i)
              msg = "#{nick.name}: I haven't actually seen #{subject_name} yet, but their account was created #{seen_at.approximate_to_s} ago."
            else
              msg = "#{nick.name}: I saw #{subject_name} #{subject_model.seen.status} #{seen_at.approximate_to_s} ago."
            end
            channel.message(msg)
          end
        else # nick is currently on channel
          if (who.last_spoke.empty?) # but hasn't said anything
            joined_at = TimeSpan.new(channel.joined_at, Time.now)
            channel.message("#{nick.name}: #{who.name} is on #{channel.name} but hasn't spoken since I joined #{joined_at.approximate_to_s} ago.")
          else # on channel, and has said something recently
            last_spoke = TimeSpan.new(who.last_spoke[:time], Time.now)
            channel.message("#{nick.name}: #{who.name} is on #{channel.name} and spoke #{last_spoke.approximate_to_s} ago: <#{who.name}> #{who.last_spoke[:text]}")
          end
        end
      rescue Exception => ex
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
          if (reason.empty?)
            status = "leaving #{channel.name}"
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
          if (reason.empty?)
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

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
