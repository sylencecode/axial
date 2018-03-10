#!/usr/bin/env ruby

require 'cgi'
require 'fileutils'
require 'marky_markov'

markov = MarkyMarkov::Dictionary.new('markov')
 text = File.open('corpus/trump_speeches.txt', 'r')
 while (line = text.gets)
   line.strip!
   if (line.empty?)
     next
   elsif (line.length < 20)
     next
   elsif (line =~ /\d+\s+(.*)/)
     match = Regexp.last_match[1].upcase
     match.gsub!(/\u201c/, '')
     match.gsub!(/\u201d/, '')
     match.gsub!(/"/, '')
     markov.parse_string(match)
   else
     next
   end
 end
 markov.save_dictionary!

puts markov.generate_4_sentences
puts markov.generate_4_sentences
puts markov.generate_4_sentences
puts markov.generate_4_sentences
