#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
doc = Nokogiri::HTML(open(ARGV[0]))
puts doc.inspect
