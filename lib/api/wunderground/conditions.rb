module Axial
  module API
    module WUnderground
      class Conditions
        attr_accessor :feels_like_c, :feels_like_f, :found, :json, :location, :relative_humidity, :temp_c, :temp_f, :visibility_mi, :weather, :wind_dir, :wind_gust_mph, :wind_mph
        def initialize()
          @feels_like_c = 0
          @feels_like_f = 0
          @found = false
          @json = ""
          @location = "unknown"
          @relative_humidity = 0
          @temp_c = 0
          @temp_f = 0
          @visibility_mi = 0
          @weather = "unknown"
          @wind_dir = "the unknown"
          @wind_gust_mph = 0
          @wind_mph = 0
        end
      end
    end
  end
end
