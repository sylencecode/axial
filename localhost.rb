#!/usr/bin/env ruby
$stdout.sync = true
$stderr.sync = true

require_relative 'lib/axial/bot.rb'

config_file = 'conf/localhost.yml'

bot = Axial::Bot.new(File.join(File.dirname(__FILE__), config_file))
bot.run
