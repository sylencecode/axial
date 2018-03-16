#!/usr/bin/env ruby

gem 'nokogiri'
require 'nokogiri'
require 'open-uri'
doc = Nokogiri::HTML(open(ARGV[0]))
puts doc.inspect
