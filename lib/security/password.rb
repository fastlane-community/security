module Security
  class Password
    attr_reader :keychain, :attributes, :password

    private_class_method :new

    def initialize(keychain, attributes, password)
      @keychain = Keychain.new(keychain)
      @attributes = attributes
      @password = password 
    end

    class << self
      private

      def password_from_output(output)
        return nil if /^security\: / === output 

        keychain, attributes, password = nil, {}, nil
        output.split(/\n/).each do |line|
          case line
          when /^keychain\: \"(.+)\"/
            keychain = $1
          when /\"(\w{4})\".+\=\"(.+)\"/
            attributes[$1] = $2
          when /^password\: \"(.+)\"/
            password = $1
          end
        end

        new(keychain, attributes, password)
      end

      def flags_for_options(options = {})
        flags = options.dup
        flags[:a] ||= options.delete(:account)
        flags[:c] ||= options.delete(:creator)
        flags[:C] ||= options.delete(:type)
        flags[:D] ||= options.delete(:kind)
        flags[:G] ||= options.delete(:value)
        flags[:j] ||= options.delete(:comment)

        flags.delete_if{|k,v| v.nil?}.collect{|k, v| "-#{k} #{v}".strip}.join(" ")
      end
    end
  end

  class GenericPassword < Password
    class << self
      def add(service, account, password, options = {})
        options[:a] = account
        options[:s] = service
        options[:w] = password

        system "security add-generic-password #{flags_for_options(options)}"
      end

      def find(options)
        options[:g] = ''

        password_from_output(`security 2>&1 find-generic-password #{flags_for_options(options)}`)
      end

      def delete(options)
        system "security delete-generic-password #{flags_for_options(options)}"
      end

      private

      def flags_for_options(options = {})
        options[:s] ||= options.delete(:service)
        super(options)
      end
    end
  end

  class InternetPassword < Password
    class << self
      def add(server, account, password, options = {})
        options[:a] = account
        options[:s] = server
        options[:w] = password
        
        system "security add-internet-password #{flags_for_options(options)}"
      end

      def find(options)
        options[:g] = ''

        password_from_output(`security 2>&1 find-internet-password #{flags_for_options(options)}`)
      end

      def delete(options)
        system "security delete-internet-password #{flags_for_options(options)}"
      end

      private

      def flags_for_options(options = {})
        options[:s] ||= options.delete(:server)
        options[:p] ||= options.delete(:path)
        options[:P] ||= options.delete(:port)
        options[:r] ||= options.delete(:protocol)
        super(options)
      end
    end
  end
end
