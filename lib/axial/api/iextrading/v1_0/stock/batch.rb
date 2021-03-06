gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'
require 'axial/api/iextrading/v1_0/stock/stock_result'

module Axial
  module API
    module IEXTrading
      module V10
        REST_API = 'https://api.iextrading.com/1.0'.freeze
        module Stock
          REST_API = API::IEXTrading::V10::REST_API + '/stock'.freeze
          class Market
            @rest_api = API::IEXTrading::V10::Stock::REST_API + '/market'.freeze
            def self.batch(symbols)
              rest_api       = @rest_api + '/batch'

              if (!symbols.is_a?(Array) || symbols.empty?)
                raise(ArgumentError, "Invalid query provided to #{self.class}: #{symbols.inspect}")
              end

              params = {}

              headers = {
                          accept: 'application/json'
                        }

              params[:symbols]    = symbols.join(',')
              params[:types]      = 'quote,news,peers,company'
              params[:range]      = 1
              params[:last]       = 1

              rest_endpoint       = URI.parse(rest_api)
              rest_endpoint.query = URI.encode_www_form(params)
              json                = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, headers: headers, verify_ssl: false)

              results_array       = API::IEXTrading::V10::Stock::StockResult.array_from_json(json)
              return results_array
            end
          end
        end
      end
    end
  end
end
