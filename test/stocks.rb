#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')
require 'axial/api/iextrading/v1_0/stock/batch.rb'

symbols = %w(AAPL)
foo = Axial::API::IEXTrading::V10::Stock::Market.batch(symbols)
foo.each do |symbol, data|
  puts "#{foo}: #{data.inspect}"
end
