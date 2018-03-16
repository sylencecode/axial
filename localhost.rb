#!/usr/bin/env ruby

require_relative './lib/irc_handler.rb'

puts RUBY_VERSION

bot = Axial::IRCHandler.new('conf/localhost.yml')
bot.run
