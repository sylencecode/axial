#!/usr/bin/env ruby

require 'sequel'
require_relative '../lib/mask_utils.rb'
require_relative '../lib/models/init.rb'
require_relative '../lib/models/mask.rb'
require_relative '../lib/models/nick.rb'


nicks = Axial::Models::Mask.get_nicks_from(ARGV[0])
puts nicks.join(', ')
