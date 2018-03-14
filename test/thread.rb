#!/usr/bin/ruby

def foo
  abort
  raise
end


Thread.abort_on_exception = false
t = Thread.new do |meh|
  begin
    foo
  rescue StandardError => ex
    puts "caught it: #{ex.class}: #{ex.message}"
  end
end

sleep 5
