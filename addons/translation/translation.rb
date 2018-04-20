require 'axial/addon'
require 'axial/api/yandex/v1_5/tr_json'
require 'axial/api/yandex/translation_result'

module Axial
  module Addons
    class Translation < Axial::Addon
      def initialize(bot)
        super

        @name                   = 'translation by yandex'
        @author                 = 'sylence <sylence@sylence.org>'
        @version                = '1.1.0'

        throttle                2

        on_channel 'arabic',    :translate_arabic
        on_channel 'chinese',   :translate_chinese
        on_channel 'english',   :translate_english
        on_channel 'french',    :translate_french
        on_channel 'german',    :translate_german
        on_channel 'hebrew',    :translate_hebrew
        on_channel 'japanese',  :translate_japanese
        on_channel 'russian',   :translate_russian
        on_channel 'spanish',   :translate_spanish
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

      def translate_german(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, 'en', 'de', text)
      end

      def translate_hebrew(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, 'en', 'he', text)
      end

      def translate_japanese(channel, nick, command)
        text = get_text(channel, nick, command)
        translate(channel, nick, 'en', 'ja', text)
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
        detected_language = API::Yandex::V15::TRJson.detect(text)
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

      def send_translation_to_channel(channel, nick, translation)
        target_text = translation.target_text
        target_text = (target_text.length >= 329) ? target_text[0..319] : target_text

        msg  = "#{Colors.gray}[#{Colors.magenta}#{translation.source_language} -> #{translation.target_language}"
        msg += "#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkmagenta}#{nick.name}#{Colors.gray}]#{Colors.reset} "
        msg += target_text
        channel.message(msg)
      end

      def translate(channel, nick, source_language, target_language, text)
        LOGGER.debug("translation request from #{nick.uhost} (#{source_language} -> #{target_language}): #{text}")

        translation = API::Yandex::V15::TRJson.translate(source_language, target_language, text)
        if (translation.target_text.empty?)
          channel.message("#{nick.name}: Couldn't translate '#{text}'")
          return
        end

        send_translation_to_channel(channel, nick, translation)
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
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
