#!/usr/bin/env ruby

require_relative '../lib/wunderground/api/q.rb'
require_relative '../lib/geonames/api/search_json.rb'

RestClient.log = 'stdout'

locsearch = GeoNames::API::SearchJSON.new
geoloc = locsearch.search(ARGV[0])
if (geoloc.found)
  loc = geoloc.to_wunderground
else
  loc = ARGV[0]
end

search = WUnderground::API::Conditions::Q.new
result = search.get_current_conditions(loc)

puts "json"
puts JSON.pretty_generate(result.json)

if (result.found)
  puts "class results:"
  result.instance_variables.each do |var|
    if (var != :@json)
      puts "#{var}: #{result.instance_variable_get(var)}"
    end
  end
else
  puts "not found"
end
