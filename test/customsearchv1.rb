#!/usr/bin/env ruby

$:.unshift(File.expand_path(File.join('..', 'lib')))
require 'api/google/custom_search/v1.rb'

result = Axial::API::Google::CustomSearch::V1.search(ARGV[0])

if (!result.snippet.empty?)
  puts result.snippet
else
  puts "not found"
end
