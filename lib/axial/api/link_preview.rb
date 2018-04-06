gem 'rest-client'
require 'rest-client'
require 'axial/api/link_preview_result'

module Axial
  module API
    module LinkPreview
      REST_API  = 'https://api.linkpreview.net'
      API_KEY   = '5abc7576a270f47fa1e27cc0c050aaf8f02272045eca0'

      def self.preview(url)
        rest_endpoint = URI.parse(API::LinkPreview::REST_API)

        headers = {
            content_type: 'application/x-www-form-urlencoded',
            accept: 'application/json'
        }

        payload = "key=#{API::LinkPreview::API_KEY}&q=#{url}"

        response = RestClient::Request.execute(method: :post, headers: headers, payload: payload, url: rest_endpoint.to_s, verify_ssl: false)

        json = JSON.parse(response)

        result = API::LinkPreviewResult.new

        if (json.has_key?('title'))
          result.title = json['title']
        end

        if (json.has_key?('description'))
          result.description = json['description']
        end

        if (json.has_key?('image'))
          result.image = json['image']
        end

        if (json.has_key?('url'))
          result.url = json['url']
        end

        return result
      rescue Exception => ex
        return nil
      end
    end
  end
end
