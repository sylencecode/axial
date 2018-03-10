#!/usr/bin/env ruby

require_relative '../lib/weatherbit/api/v20/current.rb'

RestClient.log = 'stdout'

search = WeatherBit::API::V20::Current.new
conditions = search.get_current_conditions(ARGV[0])

puts JSON.pretty_generate(conditions.json)

if (conditions.found)
  puts "#{conditions.location} | #{conditions.temp} degrees | #{conditions.conditions} | feels like: #{conditions.feels_like} | humidity: #{conditions.humidity}%"
else
  puts "not found"
end
