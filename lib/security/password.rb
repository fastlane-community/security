# frozen_string_literal: true

require 'shellwords'

module Security
  # :nodoc:
  class Password
    # `security` reports a missing item with this exit status. Every other
    # non-zero status is a failure the caller needs to know about.
    ITEM_NOT_FOUND = 44

    attr_reader :keychain, :attributes, :password

    private_class_method :new

    def initialize(keychain, attributes, password)
      @keychain = Keychain.new(keychain)
      @attributes = attributes
      @password = password
    end

    class << self
      private

      def password_from_command(command)
        result = Command.run(command)
        return nil if result.exitstatus == ITEM_NOT_FOUND
        raise Error.new(result.exitstatus, result.stderr) unless result.success?

        password_from_output(result.output)
      end

      def password_from_output(output)
        keychain = nil
        attributes = {}
        password = nil
        output.split("\n").each do |line|
          case line
          when /^keychain: "(.+)"/
            keychain = Regexp.last_match(1)
          when /"(\w{4})".+="(.+)"/
            attributes[Regexp.last_match(1)] = Regexp.last_match(2)
          when /"(\w{4})"<blob>=0x([[:xdigit:]]+)/
            attributes[Regexp.last_match(1)] = decode_hex_blob(Regexp.last_match(2))
          when /^password: "(.+)"/
            password = Regexp.last_match(1)
          when /^password: 0x([[:xdigit:]]+)/
            password = decode_hex_blob(Regexp.last_match(1))
          end
        end

        new(keychain, attributes, password)
      end

      def flags_for_options(options = {})
        flags = options.dup
        flags[:a] ||= flags.delete(:account)
        flags[:c] ||= flags.delete(:creator)
        flags[:C] ||= flags.delete(:type)
        flags[:D] ||= flags.delete(:kind)
        flags[:G] ||= flags.delete(:value)
        flags[:j] ||= flags.delete(:comment)

        flags.compact.collect { |k, v| "-#{k} #{v.shellescape}".strip }.join(' ')
      end

      def decode_hex_blob(string)
        [string].pack('H*').force_encoding('UTF-8')
      end
    end
  end

  # :nodoc:
  class GenericPassword < Password
    class << self
      def add(service, account, password, options = {})
        options[:a] = account
        options[:s] = service
        options[:w] = password

        Command.relay("security add-generic-password #{flags_for_options(options)}").success?
      end

      def find(options)
        password_from_command("security find-generic-password -g #{flags_for_options(options)}")
      end

      def delete(options)
        Command.run("security delete-generic-password #{flags_for_options(options)}").success?
      end

      private

      def flags_for_options(options = {})
        options[:s] ||= options.delete(:service)
        super
      end
    end
  end

  # :nodoc:
  class InternetPassword < Password
    class << self
      def add(server, account, password, options = {})
        options[:a] = account
        options[:s] = server
        options[:w] = password
        Command.relay("security add-internet-password #{flags_for_options(options)}").success?
      end

      def find(options)
        password_from_command("security find-internet-password -g #{flags_for_options(options)}")
      end

      def delete(options)
        Command.run("security delete-internet-password #{flags_for_options(options)}").success?
      end

      private

      def flags_for_options(options = {})
        options[:s] ||= options.delete(:server)
        options[:p] ||= options.delete(:path)
        options[:P] ||= options.delete(:port)
        options[:r] ||= options.delete(:protocol)
        super
      end
    end
  end
end
