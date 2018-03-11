module Axial
  class URIUtils
    def self.extract(in_string)
      url_array = []
      url_string = in_string.strip
      if (!url_string.empty?)
        urls = URI.extract(url_string, ['http', 'https'])
        urls.each do |url|
          while (url.end_with?')')
            url.gsub!(/\)$/, '')
          end
          while (url.end_with?']')
            url.gsub!(/\]$/, '')
          end
          while (url.end_with?'>')
            url.gsub!(/\>$/, '')
          end
          url_array.push(url)
        end
      end
      return url_array
    end
  end
end
