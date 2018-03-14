module Axial
  module API
    module TinyURL
      @tinyurl_rest_api = "https://tinyurl.com/api-create.php"
  
      def self.shorten(long_url)
        rest_endpoint = URI.parse(@tinyurl_rest_api)
    
        params = {
          url: long_url.to_s
        }
        rest_endpoint.query = URI.encode_www_form(params)
    
        response = RestClient.get(rest_endpoint.to_s)
        response_string = response.to_s.strip
    
        short_url = nil
        if (!response_string.empty?)
          short_url = response_string
        end
    
        return URI.parse(short_url)
      rescue RestClient::Exception => ex
        return nil
      end
    end
  end
end
