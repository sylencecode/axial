gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'
require 'axial/api/iextrading/v1_0/stock/stock_result'


module Axial
  module API
    module CryptoCompare
      class Data
        REST_API = 'https://api.iextrading.com/1.0'.freeze
        class Market
          @rest_api = API::CryptoCompare::Data::REST_API + '/data'.freeze

          def self.price_multi_full(symbols)
            rest_api       = @rest_api + '/pricemultifull'

            if (!symbols.kind_of?(Array) || symbols.empty?)
              raise(ArgumentError, "Invalid query provided to GeoNames: #{symbols.inspect}")
            end

            params = Hash.new

            headers = {
                        accept: 'application/json'
                      }

            params[:symbols]    = symbols.join(',')
            params[:types]      = 'quote,news,peers,company'
            params[:range]      = 1
            params[:last]       = 1

            rest_endpoint       = URI::parse(rest_api)
            rest_endpoint.query = URI.encode_www_form(params)
            response = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, headers: headers, verify_ssl: false)
            json = JSON.parse(response)

            results             = {}

            json.each do |symbol, data|
              result = API::IEXTrading::V10::Stock::StockResult.new

              if (data.has_key?('quote'))
                quote = data['quote']
                if (quote.has_key?('latestPrice'))
                  result.latest_price = quote['latestPrice'].to_f
                end
                if (quote.has_key?('high'))
                  result.high = quote['high'].to_f
                end
                if (quote.has_key?('low'))
                  result.low = quote['low'].to_f
                end
                if (quote.has_key?('change'))
                  result.change = quote['change'].to_f
                end
                if (quote.has_key?('open'))
                  result.last_open = quote['open'].to_f
                end
                if (quote.has_key?('close'))
                  result.last_close = quote['close'].to_f
                end
              end

              if (data.has_key?('news') && data['news'].is_a?(Array) && data['news'].any?)
                news = data['news'].first
                if (news.has_key?('headline'))
                  result.news[:headline] = news['headline']
                end
                if (news.has_key?('datetime'))
                  result.news[:date_time] = Time.parse(news['datetime'])
                end
              end

              if (data.has_key?('peers'))
                result.peers = data['peers']
              end

              if (data.has_key?('company'))
                company = data['company']
                if (company.has_key?('companyName'))
                  result.company_name = company['companyName']
                end
              end

              results[symbol] = result
            end
            return results
          end
        end
      end
    end
  end
end
