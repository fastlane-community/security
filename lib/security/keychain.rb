# frozen_string_literal: true

module Security
  # :nodoc:
  class Keychain
    DOMAINS = %i[user system common dynamic].freeze

    # The partition IDs that let Apple's signing tools use an imported key
    # without a keychain prompt.
    DEFAULT_PARTITION_IDS = %w[apple-tool: apple: codesign:].freeze

    attr_reader :filename

    def initialize(filename)
      @filename = filename
    end

    def info
      Command.relay('security', 'show-keychain-info', @filename).success?
    end

    def lock
      Command.relay('security', 'lock-keychain', @filename).success?
    end

    def unlock(password)
      Command.relay('security', 'unlock-keychain', '-p', password.to_s, @filename).success?
    end

    def delete
      Command.relay('security', 'delete-keychain', @filename).success?
    end

    # With no options the keychain never locks on its own.
    def update_settings(timeout: nil, lock_when_sleeping: false, lock_after_timeout: false)
      command = %w[security set-keychain-settings]
      command += ['-t', timeout.to_s] if timeout
      command << '-l' if lock_when_sleeping
      command << '-u' if lock_after_timeout

      Command.relay(*command, @filename).success?
    end

    # Raises rather than returning false: a wrong keychain password is the usual
    # failure, and the caller needs the output to tell it from the others.
    def set_key_partition_list(password, partition_ids: DEFAULT_PARTITION_IDS)
      result = Command.run('security', 'set-key-partition-list', '-S', partition_ids.join(','), '-s',
                           '-k', password.to_s, @filename)
      raise Error.new(result.exitstatus, result.stderr) unless result.success?

      true
    end

    class << self
      # Raises on failure, like the other class methods that answer with a keychain.
      def create(filename, password)
        result = Command.run('security', 'create-keychain', '-p', password.to_s, filename.to_s)
        raise Error.new(result.exitstatus, result.stderr) unless result.success?

        new(filename.to_s)
      end

      def list(domain = :user)
        keychains_from_command('security', 'list-keychains', '-d', domain_name(domain))
      end

      def set_search_list(keychains, domain: :user)
        Command.relay('security', 'list-keychains', '-d', domain_name(domain), '-s',
                      *keychains.map { |keychain| filename_for(keychain) }).success?
      end

      def lock
        Command.relay('security', 'lock-keychain', '-a').success?
      end

      def unlock(password)
        Command.relay('security', 'unlock-keychain', '-p', password.to_s).success?
      end

      def default_keychain
        keychains_from_command('security', 'default-keychain').first
      end

      def set_default_keychain(keychain, domain: :user)
        Command.relay('security', 'default-keychain', '-d', domain_name(domain), '-s', filename_for(keychain)).success?
      end

      def login_keychain
        keychains_from_command('security', 'login-keychain').first
      end

      def supports_key_partition_list?
        Command.run('security', '-h').stdout.include?('set-key-partition-list')
      end

      private

      def domain_name(domain)
        raise ArgumentError, "Invalid domain #{domain}, expected one of: #{DOMAINS}" unless DOMAINS.include?(domain)

        domain.to_s
      end

      def filename_for(keychain)
        keychain.respond_to?(:filename) ? keychain.filename : keychain.to_s
      end

      def keychains_from_command(*command)
        result = Command.run(*command)
        raise Error.new(result.exitstatus, result.stderr) unless result.success?

        keychains_from_output(result.stdout)
      end

      def keychains_from_output(output)
        output.split("\n").collect { |line| new(line.strip.gsub(/^"|"$/, '')) }
      end
    end
  end
end
