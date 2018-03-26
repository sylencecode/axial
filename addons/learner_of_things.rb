require 'axial/addon'
require 'axial/models/user'
require 'axial/models/thing'
require 'axial/timespan'

module Axial
  module Addons
    class LearnerOfThings < Axial::Addon
      def initialize(bot)
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
        user_model = Models::User.get_from_nick_object(nick)
        if (user_model.nil?)
          channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        end
        if (command.args.strip =~ /(.*)=(.*)/)
          thing_array = command.args.split('=')
          thing = thing_array.shift.strip
          explanation = thing_array.join('=').strip
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

        Models::Thing.upsert(thing, explanation, user_model)
        LOGGER.info("learned: #{thing} = #{explanation} from #{nick.uhost}")
        channel.message("#{nick.name}: ok, I've learned about #{thing}.")
      rescue StandardError => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def forget(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          thing = command.args.strip
          if (thing.empty?)
            channel.message("#{nick.name}: try ?explain <thing> instead of whatever you just did.")
            return
          end
          thing_model = Models::Thing[thing: thing.downcase]
          LOGGER.info("forgot: #{thing_model.pretty_thing} = #{thing_model.explanation} from #{nick.uhost}")
          if (thing_model.nil?)
            channel.message("#{nick.name}: I don't know about #{thing}.")
            return
          end
          thing_model.delete
          channel.message("#{nick.name}: ok, I've forgotten about #{thing}.")
        rescue StandardError => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
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
        LOGGER.info("expained #{thing_model.pretty_thing} = #{thing_model.explanation} to #{nick.uhost}")
        learned_at = Axial::TimeSpan.new(thing_model.learned_at, Time.now)
        msg  = "#{Colors.gray}[#{Colors.blue}thing#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkblue}#{nick.name}#{Colors.gray}]#{Colors.reset} "
        msg += "#{thing_model.pretty_thing} = #{thing_model.explanation} (learned from #{thing_model.user.pretty_name} #{learned_at.approximate_to_s} ago)"
        channel.message(msg)
      rescue StandardError => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def explain_on_join(channel, nick)
        user_model = Models::Mask.get_user_from_mask(nick.uhost)
        if (!user_model.nil?)
          thing_model = Models::Thing[thing: user_model.name]
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
          channel.message("#{Colors.gray}[#{Colors.reset}#{thing_subject_string}#{Colors.gray}]#{Colors.reset} #{thing_model.explanation}")
          LOGGER.debug("thing (autojoin) expained #{thing_subject_string} = #{thing_model.explanation} to #{channel.name}.")
        end
      rescue StandardError => ex
        LOGGER.error("#{self.class} error on join of #{nick.uhost} to #{channel.name}: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
