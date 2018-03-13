#!/usr/bin/env ruby

require 'sequel'
require_relative '../lib/mask_utils.rb'

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
