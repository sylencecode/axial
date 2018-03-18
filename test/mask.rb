#!/usr/bin/env ruby

gem 'sequel'
require_relative '../lib/axial/irc_types/.rb'

masks = [
  '*!~xjester@foo.com',
  'foo.com',
  'xjester@foo.com',
  'plork!~foo@foo.com',
  '~asdf@foo.com'
]

masks.each do |mask|
  puts mask + " -> " + Axial::MaskUtils.ensure_wildcard(mask)
end
