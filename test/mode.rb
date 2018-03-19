#!/usr/bin/env ruby
require_relative '../lib/axial/irc_types/mode'
#test = "+biklmnostv *!*@foo.test asdf 20 X-Jester X-Jester"

foo = Axial::IRCTypes::Mode.new
#foo.parse_string(test)
foo.invite_only = true
foo.secret = true
foo.topic_ops_only = true
puts "invite only #{foo.invite_only?}"
puts "moderated #{foo.moderated?}"
puts "nom #{foo.no_outside_messages?}"
puts "topics #{foo.topic_ops_only?}"
puts "limit #{foo.limit?} #{foo.limit}"
puts "keyword #{foo.keyword?} #{foo.keyword}"
puts "ops #{foo.ops.inspect}"
puts "deops #{foo.deops.inspect}"
puts "bans #{foo.bans.inspect}"
puts "unbans #{foo.unbans.inspect}"
puts "voices #{foo.voices.inspect}"
puts "devoices #{foo.devoices.inspect}"
puts "secret #{foo.secret?}"
puts foo.channel_modes.inspect
# foo.op("joe")
# foo.op("tom")
# foo.deop("bill")
# foo.deop("jason")
# foo.set_keyword("woot")
# puts foo.keyword
# foo.limit = 0
puts foo.to_string_array.inspect
