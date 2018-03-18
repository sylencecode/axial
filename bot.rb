#!/usr/bin/env ruby

require_relative 'lib/axial/irc_types/bot.rb'

config_file = 'conf/localhost.yml'

bot = Axial::Bot.create(config_file)
bot.run