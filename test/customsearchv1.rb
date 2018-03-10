#!/usr/bin/env ruby

require_relative '../lib/google/api/custom_search_v1.rb'

search = Google::API::CustomSearchV1.new
result = search.search(ARGV[0])

if (!result.snippet.empty?)
  puts result.snippet
else
  puts "not found"
end
