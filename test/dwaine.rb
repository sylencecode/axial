#!/usr/bin/env ruby
gem 'marky_markov'
require 'marky_markov'
require 'cgi'
require 'fileutils'

markov = MarkyMarkov::TemporaryDictionary.new
text = File.open('/home/axial/irc.efnet.#lrh.weechatlog', 'r')
while (line = text.gets)
  line.strip!
  if (line.empty?)
    next
  elsif (line =~ /\S+\s+\+{0,1}Dwaine_{0,1}\s+(.*)/)
    match = Regexp.last_match[1]
    markov.parse_string(match)
  else
    next
  end
end

ts = Time.now.strftime('%H:%M')
puts "#{ts} <Dwaine> #{markov.generate_3_sentences}"
