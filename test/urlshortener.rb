#!/usr/bin/env ruby

require_relative '../lib/uri_utils.rb'

short_url = Axial::URIUtils.shorten(ARGV[0])
puts short_url
