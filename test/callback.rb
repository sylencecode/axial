#!/usr/bin/env ruby

class IRC
  @channel_hooks = []
  def self.on_channel(regexp, callback)
    puts "Channel callback |#{regexp.inspect}| callback |#{callback}|"
    @channel_hooks.push(regexp: regexp, callback: callback)
    @channel_hooks.each do |hook, i|
      puts "Hook #{i}: #{hook}"
    end
  end
end

class Foo
  def initialize()
    puts "i got initialized"
  end
end

IRC.on_channel(/foo/, )
