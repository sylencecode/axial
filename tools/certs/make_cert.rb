#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', '../lib')))

require 'axial/cert_utils'

subject = ARGV[0]
if (ARGV.empty? || ARGV[0].nil? || ARGV[0].empty?)
  $stderr.puts "usage: #{$PROGRAM_NAME} <bot name>"
  exit 1
end

private_key, public_key = Axial::CertUtils.generate_key_pair
cert = Axial::CertUtils.sign(subject, public_key)

certs_path = File.expand_path(File.join(File.dirname(__FILE__), '../certs'))

if (!File.directory?(File.expand_path(File.dirname(__FILE__) + subject)))
  FileUtils.mkdir(File.expand_path(File.dirname(__FILE__) + subject))
end

File.open("#{certs_path}/#{subject}.key", 'w') do |key_file|
  key_file.puts(private_key.to_pem)
end

File.open("#{certs_path}/#{subject}.crt", 'w') do |cert_file|
  cert_file.puts(cert.to_pem)
end

File.open("#{certs_path}/axnet-ca.crt", 'w') do |ca_cert_file|
  ca_cert_file.puts(Axial::CertUtils.ca_cert)
end
