# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  skip '/spec/'
  skip '/vendor/'
  minimum_coverage 100
end

require_relative '../lib/security'

# rubocop:disable-next Style/MixinUsage
include Security

require 'openssl'
require 'tmpdir'

# The library wraps a real tool, so some of what it does can only be checked by
# running it. These build what those examples need rather than committing
# binaries: a throwaway keychain and a self signed certificate.
module RealSecurity
  module_function

  def with_keychain
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'spec.keychain')
      Security::Command.run('security', 'create-keychain', '-p', '', path)
      begin
        yield path
      ensure
        Security::Command.run('security', 'delete-keychain', path)
      end
    end
  end

  # Built with Ruby's OpenSSL rather than an openssl binary, whose version and defaults vary.
  def certificate_and_key
    key = OpenSSL::PKey::RSA.new(2048)
    name = OpenSSL::X509::Name.parse('/CN=security gem spec')
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = name
    cert.issuer = name
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after = Time.now + 86_400
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    [cert, key]
  end

  def with_certificate
    cert, key = certificate_and_key
    Dir.mktmpdir do |dir|
      cert_path = File.join(dir, 'cert.pem')
      key_path = File.join(dir, 'key.pem')
      File.write(cert_path, cert.to_pem)
      File.write(key_path, key.to_pem)
      yield cert_path, key_path
    end
  end

  # A certificate and its key as one PKCS#12 file. `security import` rejects OpenSSL 3's defaults, AES-256
  # and a SHA-256 MAC, so use 3DES and SHA-1. PKCS12#set_mac needs openssl gem 3.3 (Ruby 3.4).
  def with_identity(password)
    cert, key = certificate_and_key
    identity = OpenSSL::PKCS12.create(password, 'security gem spec', key, cert, nil, 'PBE-SHA1-3DES', 'PBE-SHA1-3DES')
    identity.set_mac(password, nil, nil, 'SHA1')
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'identity.p12')
      File.binwrite(path, identity.to_der)
      yield path
    end
  end

  def certificates_in(keychain)
    result = Security::Command.run('security', 'find-certificate', '-a', keychain)
    result.stdout.scan(/"labl"<blob>="(.*)"/).flatten
  end
end
