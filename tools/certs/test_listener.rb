#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', '../lib')))

require 'socket'
require 'axial/cert_utils'

context = Axial::CertUtils.get_context

tcp_listener = TCPServer.new(1234)
while (true)
  begin
    ssl_listener  = OpenSSL::SSL::SSLServer.new(tcp_listener, context)
    client_socket = ssl_listener.accept
  rescue OpenSSL::OpenSSLError => ex
    puts "#{ex.class}: #{ex.message}"
  end
end
