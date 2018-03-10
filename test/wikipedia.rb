#!/usr/bin/env ruby

require_relative '../lib/wikipedia/api/w.rb'

RestClient.log = 'stdout'


search = Wikipedia::API::W.new
article = search.search(ARGV[0])

puts "json:"
puts JSON.pretty_generate(article.json)

if (article.found)
  puts "long:"
  puts article.extract.cleanup.inspect

  puts "irc:"
  puts article.irc_extract

  puts "url:"
  puts article.url
else
  puts "not found"
end
