require 'api/yandex/v1_5/tr_json.rb'

module Axial
  module Addons
    class Translation < Axial::Addon
      def initialize()
        super

        @name    = 'translation by yandex'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?arabic',  :translate_arabic
        on_channel '?chinese', :translate_chinese
        on_channel '?english', :translate_english
        on_channel '?french',  :translate_french
        on_channel '?russian', :translate_russian
        on_channel '?spanish', :translate_spanish
      end

      def translate_arabic(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, 'en', 'ar', text)
      end

      def translate_chinese(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, 'en', 'zh', text)
      end

      def translate_english(channel, nick, command)
        text = get_text(channel, nick, command)
        detected_language = guess(text)

        if (detected_language.nil? || detected_language.empty?)
          channel.message("#{nick.name}: I can't tell what language that is.")
        else
          translate(channel, nick, detected_language, 'en', text)
        end
      end

      def translate_french(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, 'en', 'fr', text)
      end

      def translate_russian(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, 'en', 'ru', text)
      end

      def translate_spanish(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, 'en', 'es', text)
      end

      def guess(text)
        detected_language = API::Yandex::V1_5::TRJson.detect(text)
        return detected_language
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
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
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def translate(channel, nick, source_language, target_language, text)
        LOGGER.debug("translation request from #{nick.uhost} (#{source_language} -> #{target_language}): #{text}")

        translation = API::Yandex::V1_5::TRJson.translate(source_language, target_language, text)
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
