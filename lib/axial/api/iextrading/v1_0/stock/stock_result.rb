module Axial
  module API
    module IEXTrading
      module V10
        module Stock
          class StockResult
            attr_accessor   :latest_price, :high, :low, :news, :peers, :change, :last_open,
                            :last_close, :company_name, :symbol

            def initialize()
              @latest_price = 0.0
              @high         = 0.0
              @low          = 0.0
              @change       = 0.0
              @last_open    = 0.0
              @last_close   = 0.0
              @company_name = ''
              @news         = {}
              @peers        = []
              @symbol       = ''
            end
          end
        end
      end
    end
  end
end
