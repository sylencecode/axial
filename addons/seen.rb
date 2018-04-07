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
  
        on_channel   'seen|lastspoke|last',   :dcc_wrapper, :seen

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

      def seen(source, user, nick, command)
        subject_name = command.first_argument
        if (subject_name.empty?)
          reply(source, nick, "usage: #{command.command} <nick>")
          return
        elsif (subject_name.casecmp(nick.name.downcase).zero?)
          reply(source, nick, "we're all trying to find ourselves.")
          return
        elsif (subject_name.casecmp(myself.name.downcase).zero?)
          reply(source, nick, "i'm one handsome guy.")
          return
        end

        who = channel.nick_list.get_silent(subject_name)
        if (who.nil?)
          subject_model = Models::User[name: subject_name.downcase]
          if (subject_model.nil?)
            reply(source, nick, "i don't know anything about #{subject_name}.")
          else
            seen_at = TimeSpan.new(subject_model.seen.last, Time.now)
            if (subject_model.seen.status =~ /^for the first time/i)
              msg = "i haven't actually /seen/ #{subject_name} but his/her account was created #{seen_at.approximate_to_s} ago."
            else
              msg = "#{subject_name} was last seen #{subject_model.seen.status} #{seen_at.approximate_to_s} ago."
            end
            reply(source, nick, msg)
          end
        else # nick is currently on channel
          if (who.last_spoke.empty?) # but hasn't said anything
            joined_at = TimeSpan.new(channel.joined_at, Time.now)
            reply(source, nick, "#{who.name} is here now but has been idle since I joined #{joined_at.approximate_to_s} ago.")
          else # on channel, and has said something recently
            last_spoke = TimeSpan.new(who.last_spoke[:time], Time.now)
            reply(source, nick, "#{nick.name}: #{who.name} is here now and has been idle for #{last_spoke.approximate_to_s}. Last message: <#{who.name}> #{who.last_spoke[:text]}")
          end
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_kick(channel, kicker_nick, kicked_nick, reason)
        user = Models::User.get_from_nick_object(kicked_nick)
        if (!user.nil?)
          status = "getting kicked from #{channel.name} by #{kicker_nick.name} (#{reason})"
          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_join(channel, nick)
        user = Models::User.get_from_nick_object(nick)
        if (!user.nil?)
          status = "joining #{channel.name}"
          Models::Seen.upsert(user, Time.now, status)
          LOGGER.debug("updated seen for #{user.pretty_name} - #{status}")
        end
      rescue Exception => ex
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_part(channel, nick, reason)
        user = Models::User.get_from_nick_object(nick)
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
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_seen_quit(nick, reason)
        user = Models::User.get_from_nick_object(nick)
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
        reply(source, nick, "#{self.class} error: #{ex.class}: #{ex.message}")
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
