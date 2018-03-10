#!/usr/bin/env ruby

msg = "?weather paris"
b = { regexp: Regexp.new(/^\?weather/) }
foo = Regexp.new(^"(#{b[:regexp].source})\s+(.*)")
if (msg =~ foo)
  command = Regexp.last_match[1]
  args = Regexp.last_match[2]
  puts command
  puts args
end
