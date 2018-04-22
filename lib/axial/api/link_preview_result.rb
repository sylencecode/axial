require 'axial/uri_utils'

module Axial
  module API
    class LinkPreviewResult
      attr_accessor :title, :description, :image, :url

      def initialize()
        @title          = ''
        @description    = ''
        @url            = ''
      end

      def data?()
        enough_data = true
        if (@url.empty?)
          enough_data = false
        elsif (@title.empty? && @description.empty?)
          enough_data = false
        end

        return enough_data
      end

      def self.from_json(json)
        json_hash             = JSON.parse(json)
        result                = new

        raw_title             = json_hash.dig('title')        || ''
        raw_description       = json_hash.dig('description')  || ''

        title                 = URIUtils.strip_html(raw_title)
        description           = URIUtils.strip_html(raw_description)

        result.url            = json_hash.dig('url')          || ''

        result.title          = (title.length <= 80) ? title : title[0..76] + '...'
        result.description    = (description.length <= 280) ? description : description[0..276] + '...'

        return result
      end
    end
  end
end
