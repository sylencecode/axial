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
      end

      def learn(channel, nick, command)
        begin
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            channel.message("Access denied. Sorry, #{nick.name}.")
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
            channel.message("Sorry #{nick.name}, your thing name is too long (<= 64 characters).")
            return
          elsif (explanation.length > 255)
            channel.message("Sorry #{nick.name}, your thing explanation is too long (<= 255 characters).")
            return
          end

          Models::Thing.learn(thing, explanation, nick_model)
          channel.message("Okay #{nick.name}, #{thing} = #{explanation}.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          log "#{self.class} error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end

      def forget(channel, nick, command)
        begin
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            channel.message("Access denied. Sorry, #{nick.name}.")
            return
          end
          thing = command.args.strip
          if (thing.empty?)
            channel.message("#{nick.name}: try ?explain <thing> instead of whatever you just did.")
            return
          end
          log "thing request from #{nick.uhost}: #{thing}"
          thing_model = Models::Thing[thing: thing.downcase]
          if (thing_model.nil?)
            channel.message("#{nick.name}: I don't know about #{thing}.")
            return
          end
          thing_model.delete
          channel.message("Okay #{nick.name}, I've forgotten about #{thing}.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          log "#{self.class} error: #{ex.class}: #{ex.message}"
          ex.backtrace.each do |i|
            log i
          end
        end
      end

      def explain(channel, nick, command)
        begin
          thing = command.args.strip
          if (thing.empty?)
            channel.message("#{nick.name}: try ?explain <thing> instead of whatever you just did.")
            return
          end
          log "thing request from #{nick.uhost}: #{thing}"
          thing_model = Models::Thing[thing: thing.downcase]
          if (thing_model.nil?)
            channel.message("#{nick.name}: I don't know about #{thing}.")
            return
          end
          learned_at = ::TimeSpan.new(thing_model.learned_at, Time.now)
          msg  = "#{$irc_gray}[#{$irc_blue}thing#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkblue}#{nick.name}#{$irc_gray}]#{$irc_reset} "
          msg += "#{thing_model.pretty_thing} = #{thing_model.explanation}. (learned from #{thing_model.nick.pretty_nick} #{learned_at.approximate_to_s} ago)"
          channel.message(msg)
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
