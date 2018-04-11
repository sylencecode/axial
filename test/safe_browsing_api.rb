#!/usr/bin/env ruby

require_relative '../lib/google.rb'

foo = Google::SafeBrowsingAPI.new
safe = foo.safe_uri?(ARGV[0])

puts safe.inspect

# $google_api_key = "AIzaSyBP76C0JnapGJK_OlTKEv6FkJ5ReKQ5ajs"
#
#
#       rest_api = "https://safebrowsing.googleapis.com/v4/threatMatches:find"
#
#       params = Hash.new
#       params[:key]              = $google_api_key
# #      params[:fields]           = "matches"
#
#       rest_endpoint = URI::parse(rest_api)
#       rest_endpoint.query = URI.encode_www_form(params)
#
#       uri = URI::parse(rest_api)
#       uri.query = URI.encode_www_form(params)
#
#       headers = {
#         :content_type => 'application/json',
#         :accept => 'application_json'
#       }
#       payload = {
#         :client => {
#           :clientId => "axial",
#           :clientVersion => "0.1"
#         },
#         :threatInfo => {
#           :threatTypes => [ "MALWARE", "SOCIAL_ENGINEERING", "POTENTIALLY_HARMFUL_APPLICATION" ],
#           :platformTypes => [ "ANY_PLATFORM" ],
#           :threatEntryTypes => [ "URL" ],
#           :threatEntries => [
#             {
#               :url => "http://malware.testing.google.test/testing/malware/"
#             }
#           ]
#         }
#       }
#
#       response = RestClient::Request.execute(method: :post, headers: headers, payload: payload.to_json, url: rest_endpoint.to_s, verify_ssl: false)
#
#       json = JSON.parse(response)
#       puts JSON.pretty_generate(json)
