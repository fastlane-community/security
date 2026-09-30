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

require 'tmpdir'

# The library wraps a real tool, so some of what it does can only be checked by
# running it. These build what those examples need rather than committing
# binaries: a throwaway keychain, a self signed certificate, and a CMS signed
# blob of the shape `security cms -D` expects.
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

  def with_certificate
    Dir.mktmpdir do |dir|
      cert = File.join(dir, 'cert.pem')
      key = File.join(dir, 'key.pem')
      run('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-keyout', key,
          '-out', cert, '-days', '1', '-nodes', '-subj', '/CN=security gem spec')
      yield cert, key
    end
  end

  def with_signed_blob(contents)
    with_certificate do |cert, key|
      Dir.mktmpdir do |dir|
        payload = File.join(dir, 'payload')
        signed = File.join(dir, 'signed.cms')
        File.write(payload, contents)
        run('openssl', 'cms', '-sign', '-in', payload, '-signer', cert,
            '-inkey', key, '-outform', 'DER', '-nodetach', '-out', signed)
        yield signed
      end
    end
  end

  def certificates_in(keychain)
    result = Security::Command.run('security', 'find-certificate', '-a', keychain)
    result.stdout.scan(/"labl"<blob>="(.*)"/).flatten
  end

  def run(*command)
    result = Security::Command.run(*command)
    raise "#{command.join(' ')} failed: #{result.stderr}" unless result.success?

    result
  end
end
