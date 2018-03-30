require 'axial/addon'
require 'axial/api/yandex/v1_5/tr_json'

module Axial
  module Addons
    class Translation < Axial::Addon
      def initialize(bot)
        super

        @name    = 'translation by yandex'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        @language_map = {
          'ab' => 'Abkhazian',
          'aa' => 'Afar',
          'af' => 'Afrikaans',
          'ak' => 'Akan',
          'sq' => 'Albanian',
          'am' => 'Amharic',
          'ar' => 'Arabic',
          'an' => 'Aragonese',
          'hy' => 'Armenian',
          'as' => 'Assamese',
          'av' => 'Avaric',
          'ae' => 'Avestan',
          'ay' => 'Aymara',
          'az' => 'Azerbaijani',
          'bm' => 'Bambara',
          'ba' => 'Bashkir',
          'eu' => 'Basque',
          'be' => 'Belarusian',
          'bn' => 'Bengali',
          'bh' => 'Bihari',
          'bi' => 'Bislama',
          'bs' => 'Bosnian',
          'br' => 'Breton',
          'bg' => 'Bulgarian',
          'my' => 'Burmese',
          'ca' => 'Catalan',
          'ch' => 'Chamorro',
          'ce' => 'Chechen',
          'ny' => 'Chichewa',
          'zh' => 'Chinese',
          'cv' => 'Chuvash',
          'kw' => 'Cornish',
          'co' => 'Corsican',
          'cr' => 'Cree',
          'hr' => 'Croatian',
          'cs' => 'Czech',
          'da' => 'Danish',
          'dv' => 'Divehi',
          'nl' => 'Dutch',
          'dz' => 'Dzongkha',
          'en' => 'English',
          'eo' => 'Esperanto',
          'et' => 'Estonian',
          'ee' => 'Ewe',
          'fo' => 'Faroese',
          'fj' => 'Fijian',
          'fi' => 'Finnish',
          'fr' => 'French',
          'ff' => 'Fulah',
          'gl' => 'Galician',
          'ka' => 'Georgian',
          'de' => 'German',
          'el' => 'Greek',
          'gn' => 'Guaraní',
          'gu' => 'Gujarati',
          'ht' => 'Haitian',
          'ha' => 'Hausa',
          'he' => 'Hebrew',
          'hz' => 'Herero',
          'hi' => 'Hindi',
          'ho' => 'Hiri Motu',
          'hu' => 'Hungarian',
          'ia' => 'Interlingua',
          'id' => 'Indonesian',
          'ie' => 'Interlingue',
          'ga' => 'Irish',
          'ig' => 'Igbo',
          'ik' => 'Inupiaq',
          'io' => 'Ido',
          'is' => 'Icelandic',
          'it' => 'Italian',
          'iu' => 'Inuktitut',
          'ja' => 'Japanese',
          'jv' => 'Javanese',
          'kl' => 'Kalaallisut',
          'kn' => 'Kannada',
          'kr' => 'Kanuri',
          'ks' => 'Kashmiri',
          'kk' => 'Kazakh',
          'km' => 'Central Khmer',
          'ki' => 'Kikuyu',
          'rw' => 'Kinyarwanda',
          'ky' => 'Kirghiz',
          'kv' => 'Komi',
          'kg' => 'Kongo',
          'ko' => 'Korean',
          'ku' => 'Kurdish',
          'kj' => 'Kuanyama',
          'la' => 'Latin',
          'lb' => 'Luxembourgish',
          'lg' => 'Ganda',
          'li' => 'Limburgan',
          'ln' => 'Lingala',
          'lo' => 'Lao',
          'lt' => 'Lithuanian',
          'lu' => 'Luba-Katanga',
          'lv' => 'Latvian',
          'gv' => 'Manx',
          'mk' => 'Macedonian',
          'mg' => 'Malagasy',
          'ms' => 'Malay',
          'ml' => 'Malayalam',
          'mt' => 'Maltese',
          'mi' => 'Maori',
          'mr' => 'Marathi',
          'mh' => 'Marshallese',
          'mn' => 'Mongolian',
          'na' => 'Nauru',
          'nv' => 'Navajo',
          'nd' => 'North Ndebele',
          'ne' => 'Nepali',
          'ng' => 'Ndonga',
          'nb' => 'Norwegian Bokmål',
          'nn' => 'Norwegian Nynorsk',
          'no' => 'Norwegian',
          'ii' => 'Sichuan Yi',
          'nr' => 'South Ndebele',
          'oc' => 'Occitan',
          'oj' => 'Ojibwa',
          'cu' => 'Church Slavic',
          'om' => 'Oromo',
          'or' => 'Oriya',
          'os' => 'Ossetian, Ossetic',
          'pa' => 'Panjabi, Punjabi',
          'pi' => 'Pali',
          'fa' => 'Persian',
          'pox' => 'Polabian',
          'pl' => 'Polish',
          'ps' => 'Pashto, Pushto',
          'pt' => 'Portuguese',
          'qu' => 'Quechua',
          'rm' => 'Romansh',
          'rn' => 'Rundi',
          'ro' => 'Romanian',
          'ru' => 'Russian',
          'sa' => 'Sanskrit',
          'sc' => 'Sardinian',
          'sd' => 'Sindhi',
          'se' => 'Northern Sami',
          'sm' => 'Samoan',
          'sg' => 'Sango',
          'sr' => 'Serbian',
          'gd' => 'Gaelic',
          'sn' => 'Shona',
          'si' => 'Sinhala',
          'sk' => 'Slovak',
          'sl' => 'Slovenian',
          'so' => 'Somali',
          'st' => 'Southern Sotho',
          'es' => 'Spanish',
          'su' => 'Sundanese',
          'sw' => 'Swahili',
          'ss' => 'Swati',
          'sv' => 'Swedish',
          'ta' => 'Tamil',
          'te' => 'Telugu',
          'tg' => 'Tajik',
          'th' => 'Thai',
          'ti' => 'Tigrinya',
          'bo' => 'Tibetan',
          'tk' => 'Turkmen',
          'tl' => 'Tagalog',
          'tn' => 'Tswana',
          'to' => 'Tonga',
          'tr' => 'Turkish',
          'ts' => 'Tsonga',
          'tt' => 'Tatar',
          'tw' => 'Twi',
          'ty' => 'Tahitian',
          'ug' => 'Uighur',
          'uk' => 'Ukrainian',
          'ur' => 'Urdu',
          'uz' => 'Uzbek',
          've' => 'Venda',
          'vi' => 'Vietnamese',
          'vo' => 'Volapük',
          'wa' => 'Walloon',
          'cy' => 'Welsh',
          'wo' => 'Wolof',
          'fy' => 'Western Frisian',
          'xh' => 'Xhosa',
          'yi' => 'Yiddish',
          'yo' => 'Yoruba',
          'za' => 'Zhuang',
          'zu' => 'Zulu'
        }

        throttle   2

        on_channel '?arabic',    :translate_arabic
        on_channel '?chinese',   :translate_chinese
        on_channel '?english',   :translate_english
        on_channel '?french',    :translate_french
        on_channel '?german',    :translate_german
        on_channel '?hebrew',    :translate_hebrew
        on_channel '?japanese',  :translate_japanese
        on_channel '?russian',   :translate_russian
        on_channel '?spanish',   :translate_spanish
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

        msg  = "#{Colors.gray}[#{Colors.magenta}#{@language_map[source_language].downcase} -> #{@language_map[target_language].downcase}"
        msg += "#{Colors.reset} #{Colors.gray}::#{Colors.reset} #{Colors.darkmagenta}#{nick.name}#{Colors.gray}]#{Colors.reset} "
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
