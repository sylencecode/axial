#!/usr/bin/env ruby

require_relative './lib/irc_handler.rb'

bot = Axial::IRCHandler.new("localhost", 6667)
#bot = Axial::IRCHandler.new("irc.choopa.net", 6667)
bot.run
