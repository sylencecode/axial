#!/usr/bin/env ruby

module Axial
  class Plugin
    attr_accessor :listeners
    def initialize()
      @listeners = []
    end

    def on_channel(text, method)
      puts "Will invoke #{method} when text #{text} received by channel"
      @listeners.push(text: text, method: method)
    end
  end
end


class Class1 < Axial::Plugin
  def initialize()
    super
    on_channel 'text', :chat
    puts "#{self.class} registered"
  end
  def chat(channel, msg)
    puts "#{self.class} chat from #{channel}: #{msg}"
  end
end

class Class2 < Axial::Plugin
  def initialize()
    super
    puts "#{self.class} registered"
    on_channel :foo, :chat
  end
  def chat(channel, msg)
    puts "#{self.class} chat from #{channel}: #{msg}"
  end
end

class Class3 < Axial::Plugin
  def initialize()
    super
    puts "#{self.class} registered"
    on_channel :foo, :chat
  end

  def chat(channel, msg)
    puts "#{self.class} chat from #{channel}: #{msg}"
  end
end

foo = [Class1, Class2, Class3]

channel = "#test"
message = "hello there"
foo.each do |plugin|
  c = plugin.new
  puts c.listeners.inspect
  c.listeners.each do |binding|
    if (c.respond_to?(binding[:method].to_sym))
      puts "yep, responds"
      c.send(binding[:method].to_sym, channel, message)
    else
      puts "nope, does not respond"
    end
  end
end
