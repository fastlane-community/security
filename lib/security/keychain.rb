# frozen_string_literal: true

require 'open3'
require 'shellwords'

module Security
  # :nodoc:
  class Keychain
    DOMAINS = %i[user system common dynamic].freeze

    attr_reader :filename

    def initialize(filename)
      @filename = filename
    end

    def info
      system %(security show-keychain-info #{@filename.shellescape})
    end

    def lock
      system %(security lock-keychain #{@filename.shellescape})
    end

    def unlock(password)
      system %(security unlock-keychain -p #{password.shellescape} #{@filename.shellescape})
    end

    def delete
      system %(security delete-keychain #{@filename.shellescape})
    end

    class << self
      def create(filename, password)
        raise NotImplementedError
      end

      def list(domain = :user)
        raise ArgumentError, "Invalid domain #{domain}, expected one of: #{DOMAINS}" unless DOMAINS.include?(domain)

        keychains_from_command("security list-keychains -d #{domain}")
      end

      def lock
        system %(security lock-keychain -a)
      end

      def unlock(password)
        system %(security unlock-keychain -p #{password.shellescape})
      end

      def default_keychain
        keychains_from_command('security default-keychain').first
      end

      def login_keychain
        keychains_from_command('security login-keychain').first
      end

      private

      def keychains_from_command(command)
        out, err, status = Open3.capture3(command)
        raise Error.new(status.exitstatus, err) unless status.success?

        keychains_from_output(out)
      end

      def keychains_from_output(output)
        output.split("\n").collect { |line| new(line.strip.gsub(/^"|"$/, '')) }
      end
    end
  end
end
