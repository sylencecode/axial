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

        def self.from_json_hash(symbol, json_hash)
          result                = new
          result.symbol         = symbol                            || ''
          result.latest_price   = json_hash.dig('PRICE')&.to_f      || 0.0
          result.high           = json_hash.dig('HIGHDAY')&.to_f    || 0.0
          result.low            = json_hash.dig('LOWDAY')&.to_f     || 0.0
          result.change         = json_hash.dig('CHANGEDAY')&.to_f  || 0.0

          return result
        end

        def self.array_from_json(json)
          results       = []
          json_hash     = JSON.parse(json)
          raw_quotes    = json_hash.dig('RAW')

          raw_quotes.each do |symbol, currency_hash|
            data_hash   = currency_hash.dig('USD')
            result      = from_json_hash(symbol, data_hash)

            results.push(result)
          end

          return results
        end
      end
    end
  end
end
