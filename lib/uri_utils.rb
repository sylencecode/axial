require_relative '../lib/api/tiny_url.rb'
require_relative '../lib/api/google/url_shortener/v1.rb'

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

    def self.strip_html(in_string)
      text = in_string.strip
      text = Nokogiri::HTML(text).text
      text.gsub!(/\s+/, ' ')
      text.strip!
      return text
    end

    def self.extract(in_string)
      url_array = []
      url_string = in_string.strip
      if (!url_string.empty?)
        urls = URI.extract(url_string, ['http', 'https'])
        urls.each do |url|
          url = strip_extra_characters(url)
          url_array.push(url)
        end
      end
      return url_array
    end
 
    def self.shorten(in_url)
      if (in_url.is_a?(String))
        stripped_url = strip_extra_characters(in_url)
        if (stripped_url.empty?)
          raise(ArgumentError, "Empty URI provided to URLShortenerAPI")
        elsif (!(stripped_url =~ URI::regexp))
          raise(ArgumentError, "Invalid URI provided to URLShortenerAPI: #{in_url}")
        end
      else
        raise(ArgumentError, "Invalid object provided to URLShortenerAPI: #{in_url.class}")
      end

      if (stripped_url.to_s.length < @minimum_shorten_length)
        return stripped_url
      end

      skip = false
      @do_not_shorten.each do |domain|
        domain_regexp = Regexp.new('^' + Regexp.escape(domain).gsub(/\\\*/, '.*') + '$')
        if (domain_regexp.match(stripped_url))
          skip = true
          break
        end
      end

      begin
        long_url = URI.parse(stripped_url)
        short_url = API::Google::URLShortener::V1.shorten(long_url)
        if (short_url.nil?)
          short_url = API::TinyURL.shorten(long_url)
        end
        if (short_url.nil?)
          return long_url
        end
        return short_url
      rescue Exception => ex
        puts ex.inspect
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
