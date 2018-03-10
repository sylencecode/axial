#!/usr/bin/env ruby

require 'fileutils'
require 'markov_noodles'

noodle = MarkovNoodles.new
 text = File.open('eng_news-typical_2016_100K/eng_news-typical_2016_100K-sentences.txt', 'r')
 while (line = text.gets)
   line.strip!
   if (line.empty?)
     next
   elsif (line.length < 20)
     next
   elsif (line =~ /\d+\s+(.*)/)
     match = Regexp.last_match[1]
     match.gsub!(/\u201c/, '')
     match.gsub!(/\u201d/, '')
     match.gsub!(/"/, '')
     noodle.analyse_string(match)
   else
     next
   end
 end
# markov.save_dictionary!

puts noodle.generate_sentence
puts noodle.generate_sentence
puts noodle.generate_sentence
puts noodle.generate_sentence
puts noodle.generate_sentence
