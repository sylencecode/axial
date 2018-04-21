require 'axial/addon'
require 'axial/color'
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

      def print_thing_to_channel(channel, nick, thing_model, request_type)
        LOGGER.info("expained #{thing_model.pretty_thing} = #{thing_model.explanation} to #{nick.uhost} in #{channel.name}")
        learned_at = TimeSpan.new(thing_model.learned_at, Time.now)
        msg  = Color.blue_prefix(request_type, nick.name)
        msg += thing_model.pretty_thing + Color.gray(' = ') + thing_model.explanation
        msg += " (learned from #{thing_model.user.pretty_name_with_color} #{learned_at.approximate_to_s} ago)"
        channel.message(msg)
      end

      def random(channel, nick, _command)
        thing_model = Models::Thing.order(Sequel.lit('RANDOM()')).first
        print_thing_to_channel(channel, nick, thing_model, 'random thing')
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def explain(channel, nick, command)
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
        print_thing_to_channel(channel, nick, thing_model, 'explain')
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def print_autojoin_to_channel(channel, thing_model)
        channel.message(Color.gray('[ ') + thing_model.pretty_thing + Color.gray(' ] ') + thing_model.explanation)
        LOGGER.debug("thing (autojoin) expained #{thing_model.pretty_thing} = #{thing_model.explanation} to #{channel.name}")
      end

      def explain_on_join(channel, nick)
        if (@restrict_to_channels.any? && !@restrict_to_channels.include?(channel.name.downcase))
          return
        end

        user_model = Models::User.get_from_nick_object(nick)

        if (user_model.nil?) # rubocop:disable Style/ConditionalAssignment
          thing_model = Models::Thing[thing: nick.name.downcase]
        else
          thing_model = Models::Thing[thing: user_model.name]
        end

        if (thing_model.nil?)
          return
        end

        print_autojoin_to_channel(channel, thing_model)
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
