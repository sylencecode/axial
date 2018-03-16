#!/usr/bin/env ruby

require 'cgi'
require 'fileutils'
require 'marky_markov'

markov = MarkyMarkov::Dictionary.new('../maga')
#while (line = text.gets)
#  line.strip!
#  if (line.empty?)
#    next
#  elsif (line =~ /\S+\s+\+{0,1}Dwaine_{0,1}\s+(.*)/)
#    match = Regexp.last_match[1]
#    markov.parse_string(match)
#  else
#    next
#  end
#end

# markov.parse_string("It's the bowling ball test.")
# markov.parse_string("They take a bowling ball from 20 feet up in the air and drop it on the hood of the car.")
# markov.parse_string("If the hood dents, the car doesn't qualify. It's horrible.")
# markov.save_dictionary!

puts "#{markov.generate_3_sentences}"
