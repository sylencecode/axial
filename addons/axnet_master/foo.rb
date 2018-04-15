#!/usr/bin/env ruby

class Bah
  attr_reader :name
  def initialize(name, text)
    @name = name
    @text = text
  end

  def speak()
    puts @text
  end
end

foo = [
  Bah.new('dog', 'woof'),
  Bah.new('cat', 'meow'),
  Bah.new('cow', 'moo')
]

puts foo.collect(&:name).inspect
foo.each(&:speak)
