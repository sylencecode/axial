gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'
require 'axial/api/crypto_compare/crypto_result'

module Axial
  module API
    module CryptoCompare
      REST_API = 'https://min-api.cryptocompare.com'.freeze
      class Data
        @rest_api = API::CryptoCompare::REST_API + '/data'.freeze

        def self.price_multi_full(symbols)
          rest_api = @rest_api + '/pricemultifull'

          if (!symbols.is_a?(Array) || symbols.empty?)
            raise(ArgumentError, "Invalid query provided to #{self.class}: #{symbols.inspect}")
          end

          params = {}

          headers = {
              accept: 'application/json'
          }

          params[:fsyms] = symbols.join(',')
          params[:tsyms] = 'USD'

          rest_endpoint       = URI.parse(rest_api)
          rest_endpoint.query = URI.encode_www_form(params)
          response            = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, headers: headers, verify_ssl: false)
          json                = JSON.parse(response)

          results = {}

          if (json.key?('RAW'))
            raw = json['RAW']
          end
          raw.each do |symbol, tsym|
            quote = tsym['USD']
            result = API::CryptoCompare::CryptoResult.new

            if (quote.key?('PRICE'))
              result.latest_price = quote['PRICE'].to_f
            end
            if (quote.key?('HIGHDAY'))
              result.high = quote['HIGHDAY'].to_f
            end
            if (quote.key?('LOWDAY'))
              result.low = quote['LOWDAY'].to_f
            end
            if (quote.key?('CHANGEDAY'))
              result.change = quote['CHANGEDAY'].to_f
            end
            result.symbol = symbol
            results[symbol] = result
          end
          return results
        end
      end
    end
  end
end
