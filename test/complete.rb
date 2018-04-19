#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')
require 'axial/api/google/complete.rb'

foo = Axial::API::Google::Complete.search(ARGV.join(' '))
foo.results.each do |result|
  puts "query: #{result}"
end
