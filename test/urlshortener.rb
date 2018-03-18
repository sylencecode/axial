#!/usr/bin/env ruby

require_relative '../lib/axial/irc_types/rb.rb'

short_url = Axial::URIUtils.shorten(ARGV[0])
puts short_url
