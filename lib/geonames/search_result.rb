module GeoNames
  class SearchResult
    attr_accessor :admin_code1, :city, :country_code, :country_id, :country_name, :found, :json, :lat, :long, :toponym_name
    def initialize()
      @admin_code1 = ""
      @city = ""
      @country_code = ""
      @country_id = ""
      @country_name = ""
      @found = false
      @json = ""
      @lat = 0.0
      @long = 0.0
      @toponym_name = ""
    end

    # take location data and convert it to Country/State/City format, for wunderground api
    def to_wunderground()
      query_path = ""
      if (!@country_code.empty?)
        query_path += "#{@country_code.upcase}/"
      end
      # admincode1 is the state abbreviation for US cities, wunderground can use this for precision
      if (@country_code.upcase == "US" && !@admin_code1.empty?)
        query_path += "#{@admin_code1}/"
      end
      if (!city.empty?)
        query_path += @city
      end
      return query_path
    end
  end
end
