#!/usr/bin/env ruby

require_relative 'lib/timespan.rb'
time_string = "2018-01-12 19:55:13.295445"
if (time_string =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)/)
  year = $1
  month = $2
  day = $3
  hour = $4
  minute = $5
  second = $6
  before = Time.new(year, month, day, hour, minute, second)
  puts "got it: #{before}"
  puts TimeSpan.new(before, Time.now).to_s
end

