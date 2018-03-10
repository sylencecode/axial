module WebOfTrust
  class ConfidenceRating
    attr_accessor :rating, :confidence
    def initialize()
      @rating = 0
      @confidence = 0
    end
  end
end
