# frozen_string_literal: true

require 'English'
require 'open3'

module Security
  # :nodoc:
  module Command
    # TODO: replace with Data.define once Ruby 3.1 support is dropped.
    # :nodoc:
    Result = Struct.new(:stdout, :stderr, :status) do
      def success?
        !status.nil? && status.success?
      end

      def exitstatus
        status&.exitstatus
      end

      # `security` splits what it has to say across both streams: find-*-password
      # prints the attributes on stdout and the password on stderr.
      def output
        stdout + stderr
      end
    end

    module_function

    # Runs a `security` subcommand and captures what it produced. A missing
    # `security` is a failed result rather than an exception: the tool is only
    # present on macOS, and callers elsewhere should see the same failure they
    # would get from a keychain that could not answer.
    def run(command)
      Result.new(*Open3.capture3(command))
    rescue Errno::ENOENT => e
      # Nothing ran, but the child Ruby forked exited 127 before exec, which is
      # what a shell reports for a missing command, and what this library
      # produced while it still went through one.
      Result.new('', "#{e.message}\n", $CHILD_STATUS)
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
