#!/usr/bin/env ruby
$LOAD_PATH.unshift('../lib')

require 'openssl'
require 'socket'
require 'yaml'

context = OpenSSL::SSL::SSLContext::new
context.cert = OpenSSL::X509::Certificate.new(File.read('../certs/axnet.crt'))
context.key = OpenSSL::PKey::RSA.new(File.read('../certs/axnet.key'))
context.ca_file = '../certs/axnet-ca.crt'

context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
context.ssl_version = :TLSv1_2

begin
tcp_socket = TCPSocket.new('localhost', 34567)
sslsocket = OpenSSL::SSL::SSLSocket::new(tcp_socket, context)
sslsocket.connect
sslsocket.puts "foo"
while (line = sslsocket.gets)
  raw_string = line
  yml_string = line.gsub(/\0/, "\n")
  puts line.strip.inspect
#  obj = YAML.load(yml_string)
#  puts obj.inspect
#  puts obj.masks.inspect
#  puts obj.seen.inspect
#  puts obj.friend?.inspect
#  puts object.class
#  puts object.inspect
end
rescue Exception => ex
  puts "#{ex.class}: #{ex.message}"
end
