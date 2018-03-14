#!/usr/bin/env ruby

require_relative './lib/irc_handler.rb'

bot = Axial::IRCHandler.new('conf/localhost.yml')
bot.run
