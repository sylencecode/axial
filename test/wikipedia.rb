#!/usr/bin/env ruby

$:.unshift(File.expand_path(File.join('..', 'lib')))
require 'api/wikipedia/w.rb'

RestClient.log = 'stdout'

article = Axial::API::Wikipedia::W.search(ARGV[0])

puts "json:"
puts JSON.pretty_generate(article.json)

if (article.found)
  puts "long:"
  puts article.extract.inspect

  puts "irc:"
  puts article.irc_extract

  puts "url:"
  puts article.url
else
  puts "not found"
end
