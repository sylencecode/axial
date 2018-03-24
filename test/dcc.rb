#!/usr/bin/env ruby
require 'socket'
require 'timeout'
tcp = TCPServer.new(54321)
socket = nil
begin
  Timeout.timeout(10) do
    socket = tcp.accept
  end
rescue Timeout::Error
  puts "connection attempt timed out"
end

tcp.close
if (socket.nil?)
  puts "no socket"
else
  socket.puts("Enter your password.")
  auth = false
  while (foo = socket.gets)
    if (!@auth)
      socket.puts("ok you're authed")
      auth = true
    else
      socket.puts("gotcha")
    end
  end
end

system("netstat -puntl")
