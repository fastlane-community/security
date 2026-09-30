# frozen_string_literal: true

require 'openssl'

module Security
  # :nodoc:
  class Certificate
    # The tools allowed to use an imported item without asking the user. A
    # keychain prompt in the middle of a build is a hang rather than a failure,
    # which is why these are named rather than left to the default.
    DEFAULT_TRUSTED_APPLICATIONS = [
      '/usr/bin/codesign',
      '/usr/bin/security',
      '/usr/bin/productbuild',
      '/usr/bin/productsign'
    ].freeze

    # What `security import` reports for an item the keychain already holds.
    ALREADY_EXISTS = 'The specified item already exists in the keychain'

    PEM = /-----BEGIN CERTIFICATE-----\n.*?-----END CERTIFICATE-----\n/m

    attr_reader :sha1, :sha256, :pem

    private_class_method :new

    def initialize(sha1:, sha256:, pem:)
      @sha1 = sha1
      @sha256 = sha256
      @pem = pem
    end

    # The subject's common name, which is what the keychain shows as its name.
    def name
      OpenSSL::X509::Certificate.new(pem).subject.to_a.find { |key, _value, _type| key == 'CN' }&.at(1)
    end

    def delete!
      raise NotImplementedError
    end

    def verified?
      raise NotImplementedError
    end

    class << self
      # Every certificate whose name contains `name`. Finding none is not a
      # failure: `security` prints nothing and exits 0.
      def find(name:, keychain: nil)
        command = ['security', 'find-certificate', '-a', '-c', name.to_s, '-Z', '-p']
        command << filename_for(keychain) if keychain

        result = Command.run(*command)
        raise Error.new(result.exitstatus, result.stderr) unless result.success?

        certificates_from_output(result.stdout)
      end

      # Imports a certificate or identity file into `keychain`. `password` is
      # the one protecting the file, not the keychain's. Raises
      # DuplicateItemError when the keychain already holds it.
      def import(path, keychain:, password: nil, format: nil,
                 trusted_applications: DEFAULT_TRUSTED_APPLICATIONS)
        command = ['security', 'import', path.to_s, '-k', filename_for(keychain)]
        command += ['-P', password.to_s] if password
        command += ['-f', format.to_s] if format
        trusted_applications.each { |application| command += ['-T', application] }

        result = Command.run(*command)
        return true if result.success?

        # Every failure exits 1, so only the message tells a duplicate apart.
        error = result.stderr.include?(ALREADY_EXISTS) ? DuplicateItemError : Error
        raise error.new(result.exitstatus, result.stderr)
      end

      private

      def certificates_from_output(output)
        output.scan(/^SHA-256 hash: (\h+)\nSHA-1 hash: (\h+)\n(#{PEM})/m).map do |sha256, sha1, pem|
          new(sha1: sha1, sha256: sha256, pem: pem)
        end
      end

      def filename_for(keychain)
        keychain.respond_to?(:filename) ? keychain.filename : keychain.to_s
      end
    end
  end
end
