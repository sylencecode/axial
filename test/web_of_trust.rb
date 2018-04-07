#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')
require 'axial/api/web_of_trust/v0_4/public_link_json2'

foo = Axial::API::WebOfTrust::V0_4::PublicLinkJSON2.get_rating('https://www.google.com')
puts foo.inspect
