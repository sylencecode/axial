gem 'rest-client'
require 'rest-client'
gem 'nokogiri'
require 'nokogiri'
require 'axial/api/link_preview_result'

module Axial
  module API
    module LinkPreview
      REST_API  = 'https://api.linkpreview.net'.freeze
      API_KEY   = '5abc7576a270f47fa1e27cc0c050aaf8f02272045eca0'.freeze

      # submits a url to the link preview service for title and text snippets
      # @param url [String] url to preview
      # @return [LinkPreviewResult] an object representing the data retrieved from the api
      def self.preview(url)
        rest_endpoint = URI.parse(API::LinkPreview::REST_API)

        headers = {
            content_type: 'application/x-www-form-urlencoded',
            accept: 'application/json'
        }

        payload   = "key=#{API::LinkPreview::API_KEY}&q=#{url}"

        json    = RestClient::Request.execute(method: :post, headers: headers, payload: payload, url: rest_endpoint.to_s, verify_ssl: false)
        result  = API::LinkPreviewResult.from_json(json)
        return result
      rescue Exception
        return nil
      end
    end
  end
end
