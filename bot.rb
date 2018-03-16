#!/usr/bin/env ruby

require_relative 'lib/bot.rb'

Bot.config = 'conf/localhost.yml'
Bot.run
