require_relative 'confidence_rating.rb'

module WebOfTrust
  class SiteRating
    attr_accessor :domain, :trustworthiness, :child_safety, :blacklists, :categories
    def initialize()
      @domain = ""
      @trustworthiness = ConfidenceRating.new
      @child_safety = ConfidenceRating.new
      @blacklists = Array.new
      @categories = Array.new
    end
  end
end
