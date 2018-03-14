require 'api/google/translate/v2.rb'

module Axial
  module Addons
    class Translation < Axial::Addon
      def initialize()
        super

        @name    = 'translation by google'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?russian', :translate_russian
        on_channel '?spanish', :translate_spanish
        on_channel '?french',  :translate_french
      end

      def translate_russian(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, "en", "ru", text)
      end

      def translate_spanish(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, "en", "es", text)
      end

      def translate_french(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, "en", "fr", text)
      end

      def get_text(channel, nick, command)
        text = command.args.strip
        if (text.empty?)
          channel.message("#{nick.name}: please provide source text.")
          return nil
        elsif (text.length > 319)
         text = text[0..319]
        end
        return text
      end

      def translate(channel, nick, source_language, target_language, text)
        LOGGER.debug("translation request from #{nick.uhost} (#{source_language} -> #{target_language}): #{text}")

        translation = API::Google::Translate::V2.translate(source_language, target_language, text)
        if (translation.nil?)
          channel.message("#{nick.name}: Couldn't translate '#{text}'")
          return
        end

        if (translation.length > 319)
          translation = translation[0..319]
        end

        msg  = "#{Colors.gray}[#{Colors.green}#{source_language} -> #{target_language}"
        msg += "#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkgreen}#{nick.name}#{Colors.gray}]#{Colors.reset} "
        msg += translation
        channel.message(msg)
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
