#!/usr/bin/env ruby
require 'openssl'

module Axial
  module Exceptions
    class SSLCertError < Exception
    end
  end
end

x509_cert = OpenSSL::X509::Certificate.new(File.read('/home/axial/botnet.crt'))
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
