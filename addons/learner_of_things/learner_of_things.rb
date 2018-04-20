require 'axial/addon'
require 'axial/models/user'
require 'axial/models/thing'
require 'axial/timespan'
require 'securerandom'

module Axial
  module Addons
    class LearnerOfThings < Axial::Addon
      def initialize(bot)
        super

        @name    = 'learner of things'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        # change to [] to send to all channels
        @restrict_to_channels = %w[ #lulz ]

        on_channel      'explain',  :explain
        on_channel        'learn',  :learn
        on_channel       'forget',  :forget
        on_channel       'random',  :random
        on_channel  'randomthing',  :random
        on_channel        'thing',  :random

        on_join                     :explain_on_join

        throttle                    2
      end

      def learn(channel, nick, command)
        user_model = Models::User.get_from_nick_object(nick)
        if (user_model.nil?)
          channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        end

        thing_hash = parse_thing(channel, nick, command)
        if (thing_hash.empty?)
          return
        end

        thing = thing_hash[:thing]
        explanation = thing_hash[:explanation]

        Models::Thing.upsert(thing, explanation, user_model)
        LOGGER.info("learned: #{thing} = #{explanation} from #{nick.uhost}")
        channel.message("#{nick.name}: ok, I've learned about #{thing}.")
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def parse_learn_thing(channel, nick, command)
        thing_hash = {}
        thing = nil
        explanation = nil

        if (command.args.strip =~ /(.*)=(.*)/)
          thing_array = command.args.split('=')
          thing = thing_array.shift.strip
          explanation = thing_array.join('=').strip
        end

        if (thing.nil? || explanation.nil?)
          channel.message("#{nick.name}: usage: #{command.command} <thing> = <explanation>")
          return
        end

        if (thing.length > 64)
          channel.message("#{nick.name}: your thing name is too long (<= 64 characters).")
          return
        elsif (explanation.length > 255)
          channel.message("#{nick.name}: your thing explanation is too long (<= 255 characters).")
          return
        else
          thing_hash = { thing: thing, explanation: explanation }
        end
        return thing_hash
      end

      def forget(channel, nick, command) # rubocop:disable Metrics/AbcSize
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
            return
          end
          thing = command.args.strip
          if (thing.empty?)
            channel.message("#{nick.name}: usage: #{command.command} <thing>")
            return
          end
          thing_model = Models::Thing[thing: thing.downcase]
          if (thing_model.nil?)
            channel.message("#{nick.name}: I don't know anything about #{thing}.")
            return
          end
          LOGGER.info("forgot: #{thing_model.pretty_thing} = #{thing_model.explanation} from #{nick.uhost}")
          thing_model.delete
          channel.message("#{nick.name}: ok, I've forgotten about #{thing}.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def random(channel, nick, _command) # rubocop:disable Metrics/AbcSize
        thing_model = Models::Thing.order(Sequel.lit('RANDOM()')).first
        LOGGER.info("expained #{thing_model.pretty_thing} = #{thing_model.explanation} to #{nick.uhost}")
        learned_at = TimeSpan.new(thing_model.learned_at, Time.now)
        msg  = "#{Colors.gray}[#{Colors.blue}random thing#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkblue}#{nick.name}#{Colors.gray}]#{Colors.reset} "
        msg += "#{thing_model.pretty_thing} #{Colors.gray}=#{Colors.reset} #{thing_model.explanation} (learned from #{thing_model.user.pretty_name_with_color} #{learned_at.approximate_to_s} ago)"
        channel.message(msg)
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def explain(channel, nick, command) # rubocop:disable Metrics/AbcSize
        thing = command.args.strip
        if (thing.empty?)
          channel.message("#{nick.name}: usage: #{command.command} <thing>")
          return
        end
        thing_model = Models::Thing[thing: thing.downcase]
        if (thing_model.nil?)
          channel.message("#{nick.name}: I don't know anything about #{thing}.")
          return
        end
        LOGGER.info("explained #{thing_model.pretty_thing} = #{thing_model.explanation} to #{nick.uhost}")
        learned_at = TimeSpan.new(thing_model.learned_at, Time.now)
        msg  = "#{Colors.gray}[#{Colors.blue}thing#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkblue}#{nick.name}#{Colors.gray}]#{Colors.reset} "
        msg += "#{thing_model.pretty_thing} #{Colors.gray}=#{Colors.reset} #{thing_model.explanation} (learned from #{thing_model.user.pretty_name_with_color} #{learned_at.approximate_to_s} ago)"
        channel.message(msg)
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def explain_on_join(channel, nick) # rubocop:disable Metrics/AbcSize
        if (@restrict_to_channels.any? && !@restrict_to_channels.include?(channel.name.downcase))
          return
        end

        user_model = Models::User.get_user_from_mask(nick.uhost)
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
      rescue Exception => ex
        LOGGER.error("#{self.class} error on join of #{nick.uhost} to #{channel.name}: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}", __FILE__, __LINE__)
        end
      end
    end
  end
end
