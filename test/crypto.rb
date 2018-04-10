#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')
require 'axial/api/crypto_compare/data'

symbols = ARGV
foo = Axial::API::CryptoCompare::Data.price_multi_full(symbols)
foo.each do |symbol, data|
  puts "#{symbol}: #{data.inspect}"
end
