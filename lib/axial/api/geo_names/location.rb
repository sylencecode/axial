module Axial
  module API
    module GeoNames
      class Location
        attr_writer :found
        attr_accessor :admin_code1, :city, :country_code, :country_id, :lat, :long

        def initialize()
          @found = false
        end

        def found?()
          return @found
        end

        def self.from_json(json)
          json_hash = JSON.parse(json)
          location = new

          geo_names = json_hash.dig('geonames')
          if (!geo_names.is_a?(Array) || geo_names.empty?)
            return location
          end

          geo_name = geo_names.first
          location.load_geo_name(geo_name)
          return location
        end

        def load_geo_name(geo_name)
          @found        = true
          @country_code = geo_name.dig('countryCode')&.upcase || ''
          @country_id   = geo_name.dig('countryId')&.upcase   || ''
          @admin_code1  = geo_name.dig('adminCode1')&.upcase  || ''
          @city         = geo_name.dig('name')                || ''
          @lat          = geo_name.dig('lat')&.to_f           || 0.0
          @long         = geo_name.dig('lng')&.to_f           || 0.0
        end

        # take location data and convert it to Country/State/City format, for wunderground api
        def to_wunderground()
          query_path = ''
          if (!@country_code.empty?)
            query_path += @country_code.upcase + '/'
          end
          # admincode1 is the state abbreviation for US cities, wunderground can use this for precision
          if (@country_code.casecmp('US').zero? && !@admin_code1.empty?)
            query_path += @admin_code1 + '/'
          end
          if (!city.empty?)
            query_path += @city
          end
          return query_path
        end
      end
    end
  end
end
