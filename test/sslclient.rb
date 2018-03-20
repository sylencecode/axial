#!/usr/bin/env ruby
$LOAD_PATH.unshift('../lib')

require 'openssl'
require 'socket'
require 'yaml'
require 'sequel'
require_relative '../lib/axial/models/user.rb'


context = OpenSSL::SSL::SSLContext::new
context.cert = OpenSSL::X509::Certificate.new(File.read('/home/axial/botnet.crt'))
context.key = OpenSSL::PKey::RSA.new(File.read('/home/axial/botnet.key'))
context.ca_file = '/home/axial/botnet-ca.crt'

context.verify_mode = OpenSSL::SSL::VERIFY_PEER
context.ssl_version = :TLSv1_2

begin
tcp_socket = TCPSocket.new('www.sylence.org', 2020)
sslsocket = OpenSSL::SSL::SSLSocket::new(tcp_socket, context)
sslsocket.connect
while (line = sslsocket.gets)
  raw_string = line
  yml_string = line.gsub(/\0/, "\n")
  obj = YAML.load(yml_string)
  puts obj.inspect
  puts obj.masks.inspect
  puts obj.seen.inspect
  puts obj.friend?.inspect
#  puts object.class
#  puts object.inspect
end
rescue Exception => ex
  puts "#{ex.class}: #{ex.message}"
end
