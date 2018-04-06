module Axial
  module API
    class LinkPreviewResult
      attr_accessor :title, :description, :image, :url

      def initialize()
        @title          = nil
        @description    = nil
        @image          = nil
        @url            = nil
      end

      def data?()
        return (!@title.nil? && !@title.empty? && !@description.nil? && !@description.empty? && !@url.nil? && !@url.empty?)
      end

      def short_description()
        if (@description.length > 319)
          description = @description[0..319] + "..."
        else
          description = @description
        end
        return description
      end
    end
  end
end
