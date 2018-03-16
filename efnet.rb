#!/usr/bin/env ruby

require_relative './lib/irc_handler.rb'

bot = Axial::IRCHandler.new('conf/efnet.yml')
bot.run
