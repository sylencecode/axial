require 'openssl'
require 'fileutils'

class CertError < Exception
end

module Axial
  class CertUtils
      @root_dn        = '/DC=axnet/DC=local'.freeze
      @ca_dn          = "/CN=axnet ca#{@root_dn}".freeze
      @curve          = 'secp521r1'.freeze
      @ssl_version    = :TLSv1_2
      @ca_path        = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'tools', 'certs', 'ca'))
      @key_path       = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'certs'))
      @verify_mode    = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT

      @ciphers        = [
                          [ 'ECDHE-ECDSA-AES256-GCM-SHA384', 'TLSv1/SSLv3', 256, 256 ]
                        ]

      def self.generate_key_pair()
        private_key_elliptic_curve              = OpenSSL::PKey::EC.generate(@curve)
        private_key                             = private_key_elliptic_curve

        public_key_elliptic_curve               = OpenSSL::PKey::EC.new(private_key_elliptic_curve.group)
        public_key_elliptic_curve.public_key    = private_key_elliptic_curve.public_key
        public_key                              = public_key_elliptic_curve
        return [ private_key, public_key ]
      end

      def self.get_cert_cn()
        cert              = OpenSSL::X509::Certificate.new(File.read("#{@key_path}/axnet.crt"))
        x509_array  = cert.subject.to_a
        x509_fragments = x509_array.select { |subject_fragment| subject_fragment[0] == 'CN' }.flatten
        x509_cn_fragment = x509_fragments.flatten[1]
        return x509_cn_fragment
      end

      def self.get_context()
        key                     = OpenSSL::PKey::EC.new(File.read("#{@key_path}/axnet.key"))
        cert                    = OpenSSL::X509::Certificate.new(File.read("#{@key_path}/axnet.crt"))

        context                 = OpenSSL::SSL::SSLContext.new
        context.ssl_version     = @ssl_version
        context.ecdh_curves     = @curve
        context.ciphers         = @ciphers
        context.verify_mode     = @verify_mode
        context.key             = key
        context.cert            = cert
        context.ca_file         = "#{@key_path}/axnet-ca.crt"
        return context
      end

      def self.root_dn()
        return @root_dn
      end

      def self.root_dn_x509()
        return OpenSSL::X509::Name.parse(@root_dn)
      end

      def self.ca_dn_x509()
        return OpenSSL::X509::Name.parse(@ca_dn)
      end

      def self.get_ca_cert
        ca_cert = OpenSSL::X509::Certificate.new(File.read("#{@ca_path}/ca.crt"))
        return ca_cert.to_pem
      end

      def self.create_ca()
        private_key, public_key                 = generate_key_pair

        ca_cert                                 = OpenSSL::X509::Certificate.new
        ca_cert.subject                         = ca_dn_x509
        ca_cert.issuer                          = ca_dn_x509
        ca_cert.not_before                      = Time.now
        ca_cert.not_after                       = Time.now + 3650 * 24 * 60 * 60
        ca_cert.public_key                      = public_key
        ca_cert.serial                          = 0x0
        ca_cert.version                         = 2

        extension_factory                       = OpenSSL::X509::ExtensionFactory.new
        extension_factory.subject_certificate   = ca_cert
        extension_factory.issuer_certificate    = ca_cert

        ca_cert.extensions                      = [
          extension_factory.create_extension('basicConstraints', 'CA:TRUE', true),
          extension_factory.create_extension('subjectKeyIdentifier', 'hash'),
          extension_factory.create_extension('keyUsage', 'cRLSign,keyCertSign'),
          extension_factory.create_extension('crlDistributionPoints', 'URI:http://axnet-ca.axnet.local', false),
        ]

        ca_cert.sign(private_key, OpenSSL::Digest::SHA512.new)

        File.open('ca/ca.key', 'w') do |ca_key_file|
          ca_key_file.puts(private_key.to_pem)
        end

        File.open('ca/ca.crt', 'w') do |ca_cert_file|
          ca_cert_file.puts(ca_cert.to_pem)
        end
      end

      def self.sign(subject, public_key)
        ca_key                                  = OpenSSL::PKey::EC.new(File.read("#{@ca_path}/ca.key"))
        ca_cert                                 = OpenSSL::X509::Certificate.new(File.read("#{@ca_path}/ca.crt"))

        cert                                    = OpenSSL::X509::Certificate.new
        cert.subject                            = OpenSSL::X509::Name.parse("/CN=#{subject}/OU=bots#{@root_dn}")
        cert.issuer                             = ca_dn_x509
        cert.not_before                         = Time.now
        cert.not_after                          = Time.now + 3650 * 24 * 60 * 60
        cert.public_key                         = public_key
        cert.serial                             = 0x0
        cert.version                            = 2

        extension_factory                       = OpenSSL::X509::ExtensionFactory.new
        extension_factory.subject_certificate   = cert
        extension_factory.issuer_certificate    = ca_cert

        cert.extensions        = [
          extension_factory.create_extension('subjectKeyIdentifier', 'hash'),
          extension_factory.create_extension('extendedKeyUsage', 'serverAuth,clientAuth', false),
          extension_factory.create_extension('authorityKeyIdentifier', 'keyid:always,issuer:always')
        ]

        cert.sign(ca_key, OpenSSL::Digest::SHA512.new)

        return cert
      end
    end
  end
