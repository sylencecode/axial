module Axial
  module API
    module IEXTrading
      module V10
        module Stock
          class StockResult
            attr_accessor   :latest_price, :high, :low, :change, :company_name, :symbol

            def initialize()
              @latest_price = 0.0
              @high         = 0.0
              @low          = 0.0
              @change       = 0.0
              @company_name = ''
              @symbol       = ''
            end

            def self.from_json_hash(symbol, json_hash)
              result                = new
              result.symbol         = symbol                                        || ''
              result.latest_price   = json_hash.dig('quote', 'latestPrice')&.to_f   || 0.0
              result.high           = json_hash.dig('quote', 'high')&.to_f          || 0.0
              result.low            = json_hash.dig('quote', 'low')&.to_f           || 0.0
              result.change         = json_hash.dig('quote', 'change')&.to_f        || 0.0
              result.company_name   = json_hash.dig('company', 'companyName')       || symbol

              return result
            end

            def self.array_from_json(json)
              results       = []
              json_hash     = JSON.parse(json)

              json_hash.each do |symbol, data_hash|
                result      = from_json_hash(symbol, data_hash)

                results.push(result)
              end

              return results
            end
          end
        end
      end
    end
  end
end
