module Security
  class Keychain
    DOMAINS = [:user, :system, :common, :dynamic]

    attr_reader :filename

    def initialize(filename)
      @filename = filename
    end

    def info
      system %{security show-keychain-info "#{@filename}"}
    end

    def lock
      system %{security lock-keychain "#{@filename}"}
    end

    def unlock(password)
      system %{security unlock-keychain -p #{password} "#{@filename}"}
    end

    def delete
      system %{security delete-keychain "#{@filename}"}
    end

    class << self
      def create(filename, password)
        raise NotImplementedError
      end

      def list(domain = :user)
        raise ArgumentError "Invalid domain #{domain}, expected one of: #{DOMAINS}" unless DOMAINS.include?(domain)

        keychains_from_command('list-keychains', domain)
      end

      def lock
        system %{security lock-keychain -a}
      end

      def unlock(password)
        system %{security unlock-keychain -p #{password}}
      end

      def default_keychain
        keychains_from_command('default-keychain').first
      end

      def login_keychain
        keychains_from_command('login-keychain').first
      end

      private

      def keychains_from_command(command, *args)
        `security #{[command, *args].compact.join(' ')}`.split(/\n/).collect{|line| new(line.strip.gsub(/^\"|\"$/, ""))}
      end
    end    
  end
end
