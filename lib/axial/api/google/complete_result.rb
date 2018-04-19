require 'axial/uri_utils'
require 'json'

module Axial
  module API
    module Google
      class CompleteResult
        attr_accessor :results
        def initialize()
          @results    = []
        end

        def self.from_array(results_array)
          result = new
          result.results = results_array
          return result
        end
      end
    end
  end
end
