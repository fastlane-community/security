# frozen_string_literal: true

require 'open3'

module Security
  # :nodoc:
  module Command
    # :nodoc:
    Result = Struct.new(:stdout, :stderr, :status) do
      def success?
        status.success?
      end

      def exitstatus
        status.exitstatus
      end

      # `security` splits what it has to say across both streams: find-*-password
      # prints the attributes on stdout and the password on stderr.
      def output
        stdout + stderr
      end
    end

    module_function

    # Runs a `security` subcommand and captures what it produced.
    def run(command)
      Result.new(*Open3.capture3(command))
    end

    # Runs a `security` subcommand and lets the caller see what it said. The
    # tool reports on stderr whether or not it succeeded: show-keychain-info
    # prints its result there on exit 0.
    def relay(command)
      result = run(command)
      warn result.stderr.chomp unless result.stderr.empty?

      result
    end
  end
end
