#!/usr/bin/env ruby

require 'models/thing.rb'
require 'timespan.rb'

module Axial
  module Addons
    class LearnerOfThings < Axial::Addon
      def initialize()
        super

        @name    = 'learner of things'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?explain', :explain
        on_channel '?learn',   :learn
        on_channel '?forget',  :forget
        on_join                :explain_on_join
      end

      def learn(channel, nick, command)
        nick_model = Models::Nick.get_if_valid(nick)
        if (nick_model.nil?)
          channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        end
        if (command.args.strip =~ /(.*)=(.*)/)
          thing = Regexp.last_match[1].strip
          explanation = Regexp.last_match[2].strip
          if (thing.empty? || explanation.empty?)
            channel.message("#{nick.name}: try ?learn <thing> = <explanation> instead of whatever you just did.")
            return
          end
        else
          channel.message("#{nick.name}: try ?learn <thing> = <explanation> instead of whatever you just did.")
          return
        end
        
        if (thing.length > 64)
          channel.message("#{nick.name}: your thing name is too long (<= 64 characters).")
          return
        elsif (explanation.length > 255)
          channel.message("#{nick.name}: your thing explanation is too long (<= 255 characters).")
          return
        end

        Models::Thing.upsert(thing, explanation, nick_model)
        log "learned: #{thing} = #{explanation} from #{nick.uhost}"
        channel.message("#{nick.name}: ok, I've learned about #{thing}.")
      rescue StandardError => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        log "#{self.class} error: #{ex.class}: #{ex.message}"
        ex.backtrace.each do |i|
          log i
        end
      end

      def forget(channel, nick, command)
        begin
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          thing = command.args.strip
          if (thing.empty?)
            channel.message("#{nick.name}: try ?explain <thing> instead of whatever you just did.")
            return
          end
          thing_model = Models::Thing[thing: thing.downcase]
          log "forgot: #{thing_model.pretty_thing} = #{thing_model.explanation} from #{nick.uhost}"
          if (thing_model.nil?)
            channel.message("#{nick.name}: I don't know about #{thing}.")
            return
          end
          thing_model.delete
          channel.message("#{nick.name}: ok, I've forgotten about #{thing}.")
        rescue StandardError => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          log "#{self.class} error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end

      def explain(channel, nick, command)
        thing = command.args.strip
        if (thing.empty?)
          channel.message("#{nick.name}: try ?explain <thing> instead of whatever you just did.")
          return
        end
        thing_model = Models::Thing[thing: thing.downcase]
        if (thing_model.nil?)
          channel.message("#{nick.name}: I don't know about #{thing}.")
          return
        end
        log "expained #{thing_model.pretty_thing} = #{thing_model.explanation} to #{nick.uhost}"
        learned_at = Axial::TimeSpan.new(thing_model.learned_at, Time.now)
        msg  = "#{$irc_gray}[#{$irc_blue}thing#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkblue}#{nick.name}#{$irc_gray}]#{$irc_reset} "
        msg += "#{thing_model.pretty_thing} = #{thing_model.explanation}. (learned from #{thing_model.nick.pretty_nick} #{learned_at.approximate_to_s} ago)"
        channel.message(msg)
      rescue StandardError => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        log "#{self.class} error: #{ex.class}: #{ex.message}"
        ex.backtrace.each do |i|
          log i
        end
      end

      def explain_on_join(channel, nick)
        user = Models::Mask.get_nick_from_mask(nick.uhost)
        if (!user.nil?)
          thing_model = Models::Thing[thing: user.nick.downcase]
          if (!thing_model.nil?)
            thing_subject_string = nick.name # don't reveal the user's actual nick, just use the nick they joined with
          end
        else
          thing_model = Models::Thing[thing: nick.name.downcase]
          if (!thing_model.nil?)
            thing_subject_string = thing_model.pretty_thing # otherwise, explain if there is an entry for the user's current nick
          end
        end
        if (!thing_model.nil?) # if we found something, tell the channel
          channel.message("#{$irc_gray}[#{$irc_reset}#{thing_subject_string}#{$irc_gray}]#{$irc_reset} #{thing_model.explanation}")
          log "thing (autojoin) expained #{thing_subject_string} = #{thing_model.explanation} to #{channel.name}."
        end
      rescue StandardError => ex
        log "#{self.class} error on join of #{nick.uhost} to #{channel.name}: #{ex.class}: #{ex.message}"
        ex.backtrace.each do |i|
          log i
        end
      end
    end
  end
end
