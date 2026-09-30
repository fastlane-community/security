# frozen_string_literal: true

module Security
  # :nodoc:
  class ProvisioningProfile
    class << self
      # Returns the profile at `path` decoded to its plist XML.
      #
      # `security cms -D` verifies the CMS signature, and to do that macOS
      # imports the signing certificate into a keychain. Naming one here says
      # which; without it that is the user's default keychain, and parsing a
      # profile quietly adds certificates to it.
      def decode(path, keychain: nil)
        command = ['security', 'cms', '-D', '-i', path.to_s]
        command += ['-k', filename_for(keychain)] if keychain

        result = Command.run(*command)
        raise Error.new(result.exitstatus, result.stderr) unless result.success?

        result.stdout
      end

      private

      def filename_for(keychain)
        keychain.respond_to?(:filename) ? keychain.filename : keychain.to_s
      end
    end
  end
end
