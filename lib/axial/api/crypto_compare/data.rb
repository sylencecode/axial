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
          json                = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, headers: headers, verify_ssl: false)

          results_array       = API::CryptoCompare::CryptoResult.array_from_json(json)
          return results_array
        end
      end
    end
  end
end
