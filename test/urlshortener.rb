#!/usr/bin/env ruby

require_relative '../lib/google/api/url_shortener/v1/url.rb'

RestClient.log = 'stdout'

foo = Google::API::URLShortener::V1::URL.new
asdf = foo.shorten(ARGV[0])
puts asdf
