module Axial
  module API
    module CryptoCompare
      class CryptoResult
        attr_accessor :latest_price, :high, :low, :change, :symbol

        def initialize()
          @latest_price = 0.0
          @high         = 0.0
          @low          = 0.0
          @change       = 0.0
          @symbol       = ''
        end
      end
    end
  end
end
