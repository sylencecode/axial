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

              if (!symbols.kind_of?(Array) || symbols.empty?)
                raise(ArgumentError, "Invalid query provided to GeoNames: #{symbols.inspect}")
              end

              puts symbols.flatten.select{ |symbol| !symbol.empty? }.map{ |symbol| symbol.strip }.inspect

              params = Hash.new

              headers = {
                          accept: 'application/json'
                        }

              params[:symbols]  = symbols.join(',')
              params[:types]    = 'quote,news,peers'
              params[:range]    = 1
              params[:last]     = 1    

              rest_endpoint = URI::parse(rest_api)
              rest_endpoint.query = URI.encode_www_form(params)
              response = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, headers: headers, verify_ssl: false)
              json = JSON.parse(response)
              puts JSON.pretty_generate(json)
  
              result = API::IEXTrading::V10::Stock::StockResult.new
  
              json.each do |symbol, data|
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
                    result.last_open = quote['change'].to_f
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
              end
              puts result.inspect
            end
          end
        end
      end
    end
  end
end
