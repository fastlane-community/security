# frozen_string_literal: true

module Security
  # :nodoc:
  class Error < StandardError
    attr_reader :status, :output

    def initialize(status, output)
      @status = status
      @output = output

      details = output.strip
      super(details.empty? ? "`security` exited with status #{status}" : "#{details} (status #{status})")
    end
  end
end
