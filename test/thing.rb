#!/usr/bin/env ruby

$:.unshift('../lib')
require_relative '../lib/models/init.rb'
require_relative '../lib/models/thing.rb'

module Axial
  thing = "foo"
  thing_model = Models::Thing[thing: thing]
  if (thing_model.nil?)
    puts "I don't know about #{thing}."
  else
    puts thing_model.inspect
    puts thing_model.nick.inspect
    puts thing_model.nick.things.inspect
  end
end
