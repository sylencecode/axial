#!/usr/bin/env ruby

require_relative 'lib/bot.rb'

config_file = 'conf/localhost.yml'

bot = Axial::Bot.create(config_file)
bot.run