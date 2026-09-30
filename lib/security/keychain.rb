# frozen_string_literal: true

module Security
  # :nodoc:
  class Keychain
    DOMAINS = %i[user system common dynamic].freeze

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

    class << self
      def create(filename, password)
        raise NotImplementedError
      end

      def list(domain = :user)
        keychains_from_command('security', 'list-keychains', '-d', domain_name(domain))
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

      def login_keychain
        keychains_from_command('security', 'login-keychain').first
      end

      private

      def domain_name(domain)
        raise ArgumentError, "Invalid domain #{domain}, expected one of: #{DOMAINS}" unless DOMAINS.include?(domain)

        domain.to_s
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
