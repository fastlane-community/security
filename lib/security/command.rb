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

    # What `security -i` reads at most: bytes per line, and arguments per command.
    INTERACTIVE_LINE_LENGTH = 4096
    INTERACTIVE_ARGUMENTS = 32

    module_function

    # Runs a `security` subcommand and captures what it produced. A missing
    # `security` is a failed result rather than an exception: the tool is only
    # present on macOS, and callers elsewhere should see the same failure they
    # would get from a keychain that could not answer.
    #
    # Never through a shell, so a path containing a space or a quote needs no
    # escaping:
    #
    #   run("security", "show-keychain-info", path)
    def run(program, *, stdin: nil)
      # [program, program] rather than program: Ruby hands a lone string with
      # shell metacharacters to a shell.
      # stdin_data only when there is some, so a command without a password is
      # run, and can be stubbed, exactly as before.
      Result.new(*Open3.capture3([program, program], *, **(stdin ? { stdin_data: stdin } : {})))
    rescue Errno::ENOENT => e
      # Nothing ran, but the child Ruby forked exited 127 before exec, which is
      # what a shell reports for a missing command, and what this library
      # produced while it still went through one.
      Result.new('', "#{e.message}\n", $CHILD_STATUS)
    end

    # Runs a `security` subcommand and lets the caller see what it said. The
    # tool reports on stderr whether or not it succeeded: show-keychain-info
    # prints its result there on exit 0.
    def relay(*command)
      relayed(run(*command))
    end

    # Runs a `security` subcommand that takes a password: through `security -i`,
    # which reads the command from stdin, so the password never shows in the
    # arguments, which any local user can read with `ps`. Without -p (or -P),
    # the tool would instead read it from the terminal when there is one, or
    # import would ask through a dialog.
    #
    #   run_interactive("unlock-keychain", "-p", password, path)
    def run_interactive(subcommand, *)
      result = run('security', '-i', stdin: interactive_input(subcommand, *))
      # -i adds a line naming the command and its status after any error.
      result.stderr = result.stderr.sub(/^#{Regexp.escape(subcommand)}: returned -?\d+\n\z/, '')
      result
    end

    def relay_interactive(*command)
      relayed(run_interactive(*command))
    end

    # One command line for `security -i`: every argument double quoted, with
    # backslashes and double quotes escaped. A line break would end the command,
    # and a longer line or more arguments than the tool reads would be cut.
    def interactive_input(*command)
      if command.size > INTERACTIVE_ARGUMENTS
        raise ArgumentError, "security -i takes at most #{INTERACTIVE_ARGUMENTS} arguments"
      end

      line = command.map do |argument|
        argument = argument.to_s
        raise ArgumentError, 'An argument for security -i cannot contain a line break' if argument.match?(/[\r\n]/)

        %("#{argument.gsub(/[\\"]/) { |character| "\\#{character}" }}")
      end.join(' ')
      if line.bytesize >= INTERACTIVE_LINE_LENGTH - 1
        raise ArgumentError, "A command for security -i must be shorter than #{INTERACTIVE_LINE_LENGTH} bytes"
      end

      "#{line}\n"
    end

    def relayed(result)
      warn result.stderr.chomp unless result.stderr.empty?

      result
    end
  end
end
