#!/usr/bin/env ruby

require_relative '../lib/models/init.rb'
require_relative '../lib/models/mask.rb'
require_relative '../lib/models/nick.rb'
require_relative '../lib/models/seen.rb'

module Axial
  statuses = [
    'Leaving IRC 1',
#    'Leaving IRC 2',
#    'Leaving IRC 3',
#    'Leaving IRC 4',
#    'Leaving IRC 4'
  ]
  
  uhosts = [
#    'sylence!sylence@bellatrix.sylence.org',
    'chimp!uid257001@id-257001.hathersage.irccloud.com'
#    'Nick2!~xjester@love.foo.dong.org',
#    'Nick3!xjester@asdf-1234.foo.irccloud.com',
#    'Nick4!~peeps@192.168.1.9',
#    'Nick5!~foo@2001:19f0:7400:8645::dab:eeec:0',
  ]
  
  # sample nick registration with mask
  uhosts.each_with_index do |uhost, i|
    nick = ::Axial::Nick.from_uhost(nil, uhost)
    if (Models::Nick.get_from_nick(nick).nil?)
      puts "Nick #{nick.name} does not exist, creating"
      Models::Nick.create_from_nick(nick)
    else
      puts "Nick #{nick.name} already exists"
    end
  end
  
  puts '---records created---'
  
#  Models::Nick[2].add_mask(Mask[1])
  
  puts "nicks for #{Models::Mask[3].mask}: #{Models::Mask[3].possible_nicks.inspect}"
#  puts "uhosts for #{Models::Nick[1].nick}: #{Models::Mask[1].possible_nicks.inspect}"
#  puts "uhosts for #{Models::Nick[2].nick}: #{Models::Mask[2].possible_nicks.inspect}"
#  puts "uhosts for #{Models::Nick[3].nick}: #{Models::Mask[3].possible_nicks.inspect}"
#  puts "uhosts for #{Models::Nick[4].nick}: #{Models::Mask[4].possible_nicks.inspect}"
  
  # puts "seen for #{Nick[1].nick}: #{Seen[Nick[1]].inspect]}"
  puts "seen for #{Models::Nick[3].nick}: #{Models::Nick[3].seen.status}"
  puts "masks for #{Models::Seen[3].nick.nick}: #{Models::Seen[3].nick.masks}"
  
  uhosts.each_with_index do |uhost, i|
    puts "#{i + 1}"
    uhosts.each do |host|
      nick = ::Axial::Nick.from_uhost(nil, uhost)
      if (Models::Nick[nick: nick.name.downcase].match_mask?(uhost))
        puts "yes|#{nick.name}|#{uhost}|"
      end
    end
  end
  
  # test = 'X-Jester!~xjester@suck.a.fat.dong.org'
  # should = '*@*.dong.org'
  
  # maskmatch = Regexp.new('^' + should + '$')
  # puts maskmatch.inspect
  # Mask.grep(:mask, '%.suck.org').each do |i|
  #   puts i.inspect
  # end
end
