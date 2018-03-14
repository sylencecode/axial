#!/usr/bin/env ruby

require_relative '../lib/geonames/api/search_json.rb'



search = GeoNames::API::SearchJSON.new
result = search.search(ARGV[0])

puts "json:"
puts JSON.pretty_generate(result.json)

if (result.found)
  puts result.inspect
  puts "Endpoint: http://api.wunderground.com/api/\#{wunderground_api_key}/q/#{result.to_wunderground}"
else
  puts "not found"
end
