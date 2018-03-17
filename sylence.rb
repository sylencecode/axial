#!/usr/bin/env ruby
$stdout.sync = true
$stderr.sync = true

require_relative 'lib/bot.rb'

config_file = 'conf/sylence.yml'

bot = Axial::Bot.create(config_file)
bot.run