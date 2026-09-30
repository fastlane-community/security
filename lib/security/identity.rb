# frozen_string_literal: true

module Security
  # :nodoc:
  class Identity
    attr_reader :sha1, :name, :status

    private_class_method :new

    # `status` is what `security` prints after the name for an identity it
    # considers invalid, such as CSSMERR_TP_CERT_REVOKED, or nil.
    def initialize(sha1, name, status = nil)
      @sha1 = sha1
      @name = name
      @status = status
    end

    class << self
      # The identities `security` can see, newest tool output shaped like:
      #
      #   1) A1B2... "Apple Development: someone (TEAM)"
      #      1 valid identities found
      #
      # `valid_only` drops the ones the tool marks unusable. `keychain` limits
      # the search to one; without it `security` searches the user's default,
      # which is what `find-identity` does and why callers that do not name a
      # keychain get whatever happens to be in the login one.
      def find(policy: 'codesigning', valid_only: true, keychain: nil)
        command = %w[security find-identity]
        command << '-v' if valid_only
        command += ['-p', policy.to_s] if policy
        command << filename_for(keychain) if keychain

        result = Command.run(*command)
        raise Error.new(result.exitstatus, result.stderr) unless result.success?

        identities_from_output(result.stdout)
      end

      private

      # Finding none is not a failure: `security` prints "0 valid identities
      # found" and exits 0.
      def identities_from_output(output)
        output.scan(/^\s*\d+\)\s+(\h+)\s+"(.*)"(?:\s+\(([^()]*)\))?\s*$/).map do |sha1, name, status|
          new(sha1, name, status)
        end
      end

      def filename_for(keychain)
        keychain.respond_to?(:filename) ? keychain.filename : keychain.to_s
      end
    end
  end
end
