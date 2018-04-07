module Axial
  module API
    module WebOfTrust
      class SiteRating
        attr_accessor :domain, :trustworthiness
        def initialize()
          @domain = ""
          @blacklists = Array.new
          @categories = Array.new
        end
      end
    end
  end
end

