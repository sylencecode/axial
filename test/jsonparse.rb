#!/usr/bin/env ruby

require 'json'
require 'rest-client'

rest_endpoint = URI.parse(ARGV[0])
json = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)
json_hash = JSON.parse(json)

puts JSON.pretty_generate(json_hash)
