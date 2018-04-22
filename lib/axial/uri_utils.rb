require 'axial/api/tiny_url'
require 'axial/api/google/url_shortener/v1'

module Axial
  class URIUtils
    @minimum_shorten_length = 30
    @do_not_shorten         = [
      'bit.ly',
      'goo.gl',
      't.co',
      'tinyurl.com',
      'youtu.be'
    ]

    def self.strip_html(text)
      text = text.strip
      text = Nokogiri::HTML(text).text
      text.gsub!(/\s+/, ' ')
      text.strip!
      return text
    end

    def self.extract(in_string)
      string_parts = in_string.strip.split(/\s+/)
      url_array = []

      string_parts.each do |string_part|
        if (string_part =~ /^www\.\S+\.\S+/)
          string_part = 'http://' + string_part
        end

        urls = URI.extract(string_part, [ 'http', 'https' ]) # rubocop:disable Style/WordArray
        urls.each do |url|
          url = strip_extra_characters(url)
          url_array.push(url)
        end
      end

      return url_array.uniq
    end

    def self.should_shorten?(stripped_url)
      should_shorten = true
      if (stripped_url.to_s.length >= @minimum_shorten_length)
        @do_not_shorten.each do |domain|
          domain_regexp = Regexp.new('^' + Regexp.escape(domain).gsub(/\\\*/, '.*') + '$')
          if (domain_regexp.match(stripped_url))
            should_shorten = false
            break
          end
        end
      end

      return should_shorten
    end

    def self.shorten(in_url)
      if (!in_url.is_a?(String))
        raise(ArgumentError, "Invalid object provided to URLShortenerAPI: #{in_url.class}")
      end

      stripped_url = strip_extra_characters(in_url)
      if (stripped_url.empty? || stripped_url !~ URI::DEFAULT_PARSER.make_regexp)
        raise(ArgumentError, "Invalid URI provided to URLShortenerAPI: #{in_url}")
      end

      if (!should_shorten?(stripped_url))
        return stripped_url
      end

      shortened_url = invoke_shorten_api(stripped_url)
      return shortened_url
    end

    def self.invoke_shorten_api(stripped_url)
      begin
        long_url = URI.parse(stripped_url)
        short_url = API::Google::URLShortener::V1.shorten(long_url) || API::TinyURL.shorten(long_url)
        if (short_url.nil?)
          return long_url
        end

        return short_url
      rescue Exception => ex
        LOGGER.warn("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.warn(i)
        end

        return stripped_url
      end
    end

    def self.strip_extra_characters(in_url)
      stripped_url = in_url.strip
      while (stripped_url.end_with?')')
        stripped_url.gsub!(/\)$/, '')
      end

      while (stripped_url.end_with?']')
        stripped_url.gsub!(/\]$/, '')
      end

      while (stripped_url.end_with?'>')
        stripped_url.gsub!(/\>$/, '')
      end
      return stripped_url
    end
  end
end
