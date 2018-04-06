gem 'rest-client'
require 'rest-client'
require 'axial/api/link_preview_result'
require 'nokogiri'

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
          result.title = Nokogiri::HTML(json['title']).text
        end

        if (json.has_key?('description'))
          result.description = Nokogiri::HTML(json['description']).text
        end

        if (json.has_key?('image'))
          result.image = Nokogiri::HTML(json['image']).text
        end

        if (json.has_key?('url'))
          result.url = json['url']
        end

        if (result.title.empty?)
          result.title = '<untitled>'
        end

        if (result.description.empty?)
          result.description = '<no description>'
        end
        return result
      rescue Exception => ex
        return nil
      end
    end
  end
end
