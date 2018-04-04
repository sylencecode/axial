#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')
require 'axial/api/iextrading/v1_0/stock/batch.rb'

symbols = %w(AAPL)
Axial::API::IEXTrading::V10::Stock::Market.batch(symbols)
