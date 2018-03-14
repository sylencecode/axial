#!/usr/bin/env ruby

module Axial
  module Addons
    class Seen < Axial::Addon
      def initialize()
        super

        @name    = 'last seen'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?seen', :seen
        on_join    :update_seen_join
        on_part    :update_seen_part
        on_quit    :update_seen_quit
        #on_kick    :update_seen_kick
      end

      def seen(channel, nick, command)
        who = command.args.strip
        if (who.empty?)
          channel.message("#{nick.name}: try ?seen <nick> instead of whatever you just did.")
          return
        end
        user_model = Models::Nick[nick: who.downcase]
        if (user_model.nil?)
          channel.message("#{nick.name}: I don't recall seeing #{who}.")
          return
        end
        seen_at = Axial::TimeSpan.new(user_model.seen.last, Time.now)
        log "reported seeing #{user_model.pretty_nick} to #{nick.uhost}"
        msg = "#{nick.name}: #{who} was last seen #{user_model.seen.status} #{seen_at.approximate_to_s} ago."
        channel.message(msg)
      rescue StandardError => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        log "#{self.class} error: #{ex.class}: #{ex.message}"
        ex.backtrace.each do |i|
          log i
        end
      end
        
      def update_seen_join(channel, nick)
        user = Models::Mask.get_nick_from_mask(nick.uhost)
        if (!user.nil?)
          user.seen.update(last: Time.now, status: "joining #{channel.name}")
          log "updated seen for #{user.pretty_nick} (joining #{channel.name})"
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        log "#{self.class} error: #{ex.class}: #{ex.message}"
        ex.backtrace.each do |i|
          log i
        end
      end

      def update_seen_part(channel, nick, reason)
        user = Models::Mask.get_nick_from_mask(nick.uhost)
        if (!user.nil?)
          if (reason.empty?)
            user.seen.update(last: Time.now, status: "leaving #{channel.name}")
            log "updated seen for #{user.pretty_nick} (leaving #{channel.name})"
          else
            user.seen.update(last: Time.now, status: "leaving #{channel.name} (#{reason})")
            log "updated seen for #{user.pretty_nick} (leaving #{channel.name}, reason: #{reason})"
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        log "#{self.class} error: #{ex.class}: #{ex.message}"
        ex.backtrace.each do |i|
          log i
        end
      end

      def update_seen_quit(nick, reason)
        user = Models::Mask.get_nick_from_mask(nick.uhost)
        if (!user.nil?)
          if (reason.empty?)
            user.seen.update(last: Time.now, status: "quitting IRC")
            log "updated seen for #{user.pretty_nick} (quitting IRC)"
          else
            user.seen.update(last: Time.now, status: "quitting IRC (#{reason})")
            log "updated seen for #{user.pretty_nick} (quitting IRC, reason: #{reason})"
          end
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
