#!/usr/bin/env ruby

$:.unshift('../lib')
require_relative '../lib/axial/models/init.rb'
require_relative '../lib/axial/models/thing.rb'

module Axial
  thing = "foo"
  thing_model = Models::Thing[thing: thing.downcase]
  if (thing_model.nil?)
    puts "I don't know about #{thing}."
  else
    puts thing_model.inspect
    thing_model.update(thing: "foo", pretty_thing: "FOOO", explanation: "FOO")
  end
end
