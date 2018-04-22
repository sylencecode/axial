module Axial
  module API
    module WebOfTrust
      class Rating
        attr_accessor :warnings

        def initialize()
          @warnings = []
        end

        def load_category(category) # rubocop:disable Metrics/PerceivedComplexity
          category = category.to_i
          if (category.between?(100, 199) && !@warnings.include?('harmful'))
            @warnings.push('harmful')
          elsif (category.between?(201, 299) && !@warnings.include?('suspicious'))
            @warnings.push('suspicious')
          elsif (category.between?(400, 403) && !@warnings.include?('NSFW'))
            @warnings.push('NSFW')
          end
        end

        def self.from_json(json)
          json_hash   = JSON.parse(json)
          rating      = new

          categories = json_hash.values.first.dig('categories')
          if (categories.nil? || !categories.is_a?(Hash) || categories.empty?)
            return rating
          end

          categories.each do |category, confidence|
            if (confidence < 10)
              next
            end

            rating.load_category(category)
          end

          return rating
        end
      end
    end
  end
end
