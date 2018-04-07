#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')
require 'axial/api/web_of_trust/v0_4/public_link_json2'

foo = Axial::API::WebOfTrust::V0_4::PublicLinkJSON2.get_rating(ARGV[0])
puts "domain: #{foo.domain}"
#puts "trustworthiness: #{foo.trustworthiness.rating} (#{foo.trustworthiness.confidence} confidence)"
#puts "child safety: #{foo.child_safety.rating} (#{foo.child_safety.confidence} confidence)"
#puts "categories: #{foo.categories.join(', ')}"
if (foo.categories.include?(:good_site))
  puts "this looks like a good site"
end
puts "blacklists: #{foo.blacklists.join(', ')}"
# components
# blacklists
