#!/usr/bin/env ruby

$:.unshift(File.expand_path(File.join('..', 'lib')))

require 'api/wunderground/q.rb'
require 'api/geo_names/search_json.rb'


geoloc = Axial::API::GeoNames::SearchJSON.search(ARGV[0])
if (geoloc.found)
  loc = geoloc.to_wunderground
else
  loc = ARGV[0]
end

result = Axial::API::WUnderground::Q.get_current_conditions('22205')

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
