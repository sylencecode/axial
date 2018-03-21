gem 'marky_markov'
require 'marky_markov'
require 'axial/addon'

module Axial
  module Addons
    class MAGA < Axial::Addon
      def initialize(bot)
        super

        @markov  = MarkyMarkov::Dictionary.new('maga')
        @name    = 'MAGA'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?maga',  :send_maga
        on_channel '?trump', :send_maga
      end

      def send_maga(channel, nick, command)
        if (command.args.strip =~ /^reload$/)
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          LOGGER.info("MAGA dictionary reloaded by #{nick.uhost}")
          @markov = MarkyMarkov::Dictionary.new('maga')
          channel.message("#{nick.name}: ok, reloaded MAGA dictionary.")
        elsif (command.args.strip =~ /^learn\s+(\S+.*)$/)
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          new_sentence = Regexp.last_match[1].strip
          @markov.parse_string(new_sentence.upcase)
          @markov.save_dictionary!
          channel.message("#{nick.name}: ok, updated MAGA dictionary.")
        else
          LOGGER.debug("MAGA request from #{nick.uhost}")
          msg  = "#{Colors.gray}[#{Colors.red}MAGA!#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkred}#{nick.name}#{Colors.gray}]#{Colors.reset} "
          msg += @markov.generate_4_sentences
          channel.message(msg)
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
