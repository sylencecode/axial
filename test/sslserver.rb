#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')

require 'openssl'
require 'socket'
require 'yaml'
require 'sequel'
require_relative '../lib/axial/models/user.rb'

module Axial
  module Exceptions
    class SSLCertError < Exception
    end
  end
end

context = OpenSSL::SSL::SSLContext::new
#context.verify_mode = OpenSSL::SSL::VERIFY_PEER
context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
context.cert = OpenSSL::X509::Certificate.new(File.read('/home/axial/botnet.crt'))
context.key = OpenSSL::PKey::RSA.new(File.read('/home/axial/botnet.key'))
context.ca_file = '/home/axial/botnet-ca.crt'
context.ssl_version = :TLSv1_2

context.ciphers = [
  ["DHE-RSA-AES256-GCM-SHA384", "TLSv1/SSLv3", 256, 256],
]

tcp_port = 34567

tcp_listener = TCPServer.new(tcp_port)
loop do
  begin
  listener = OpenSSL::SSL::SSLServer::new(tcp_listener, context)
  client = listener.accept()
  x509_cert = client.context.cert

  x509_array = x509_cert.subject.to_a
  if (x509_array.count == 0)
    raise(Axial::Exceptions::SSLCertError, "No subject info found in certificate: #{x509_cert.inspect}")
  end

  x509_fragments = x509_array.select{|subject_fragment| subject_fragment[0] == 'CN'}.flatten
  if (x509_fragments.count == 0)
    raise(Axial::Exceptions::SSLCertError, "No CN found in #{x509_array.inspect}")
  end
  
  x509_cn_fragment = x509_fragments.flatten
  if (x509_cn_fragment.count < 3)
    raise(Axial::Exceptions::SSLCertError, "CN fragment appears to be corrupt: #{x509_cn_fragment.inspect}")
  end
  
  user_cn = x509_cn_fragment[1]
  
  puts user_cn.inspect
#  foo = YAML::dump(client)
  big_array = []
#  20.times do
#    little_array = []
#    little_array.push(File.read('sequel.rb'))
#    big_array.push(little_array)
#  end
#  puts "objects: #{big_array.count}"
  Axial::Models::User.each do |user|
    raw_yml = YAML.dump(user.masks)
    packet = raw_yml.gsub(/\n/, "\0")
    client.puts(packet)
    puts "end stream"
  end
  rescue OpenSSL::SSL::SSLError => ex
    puts "#{ex.class}: #{ex.message}"
    puts "#{ex.inspect}"
  end
end
