#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', '../lib')))

require 'socket'
require 'axial/cert_utils'

context = Axial::CertUtils.get_context

begin
  tcp_socket = TCPSocket.new('localhost', 1234)
  ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, Axial::CertUtils.get_context)
  server_socket = ssl_socket.connect
  puts server_socket.io.inspect
  while (server_socket.gets)
    puts "got something"
    sleep 1
  end
  puts server_socket.eof?
  puts server_socket.closed?
rescue OpenSSL::OpenSSLError => ex
  puts "#{ex.class}: #{ex.message}"
end
