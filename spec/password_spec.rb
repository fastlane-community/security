# frozen_string_literal: true

describe GenericPassword do
  let(:service) { 'com.example.service' }
  let(:account) { 'jappleseed' }
  let(:password) { 'p4ssw0rd!' }
  let(:comment) { 'Some comment' }

  describe '#add' do
    it 'should add the password and attributes to the given keychain' do
      RealSecurity.with_keychain do |filename|
        expect(GenericPassword.add(service, account, password, comment: comment, keychain: filename)).to be true

        entry = GenericPassword.find(account: account, keychain: filename)
        expect(entry.keychain.filename).to be == filename
        expect(entry.attributes).to include('acct' => account, 'svce' => service, 'icmt' => comment)
        expect(entry.password).to be == password
      end
    end

    it 'should store a password containing shell syntax as given' do
      RealSecurity.with_keychain do |filename|
        tricky = %q(it's $HOME && `true` ; "quoted")
        expect(GenericPassword.add(service, account, tricky, keychain: filename)).to be true

        expect(GenericPassword.find(service: service, keychain: filename).password).to be == tricky
      end
    end

    it 'should accept a Keychain object' do
      RealSecurity.with_keychain do |filename|
        keychain = Keychain.new(filename)
        expect(GenericPassword.add(service, account, password, keychain: keychain)).to be true

        entry = GenericPassword.find(service: service, keychain: keychain)
        expect(entry.keychain.filename).to be == filename
        expect(entry.password).to be == password
      end
    end
  end

  describe '#find' do
    it 'should return nil when the password is in another keychain' do
      RealSecurity.with_keychain do |first|
        expect(GenericPassword.add(service, account, password, keychain: first)).to be true

        RealSecurity.with_keychain do |second|
          expect(GenericPassword.find(service: service, keychain: second)).to be_nil
        end
      end
    end

    it 'should raise an error carrying the status and the output when the security command fails' do
      RealSecurity.with_keychain do |filename|
        expect { GenericPassword.find(Z: 'bogus', keychain: filename) }.to raise_error(Security::Error) do |error|
          expect(error.status).to be == 2
          expect(error.message).to match(/illegal option/)
        end
      end
    end
  end

  describe '#delete' do
    it 'should delete the password from the given keychain' do
      RealSecurity.with_keychain do |filename|
        expect(GenericPassword.add(service, account, password, keychain: filename)).to be true

        expect(GenericPassword.delete(service: service, keychain: filename)).to be true
        expect(GenericPassword.find(service: service, keychain: filename)).to be_nil
      end
    end
  end
end

describe InternetPassword do
  let(:server) { 'example.com' }
  let(:account) { 'jappleseed@example.com' }

  describe '#add' do
    shared_examples 'an internet password' do
      it 'should add the password and attributes to the given keychain' do
        RealSecurity.with_keychain do |filename|
          expect(InternetPassword.add(server, account, password, comment: comment, keychain: filename)).to be true

          entry = InternetPassword.find(account: account, keychain: filename)
          expect(entry.keychain.filename).to be == filename
          expect(entry.attributes).to include('acct' => account, 'srvr' => server)
          expect(entry.attributes['icmt']).to be == comment if comment
          expect(entry.password).to be == password
        end
      end
    end

    describe 'ascii password' do
      let(:password) { 'p4ssw0rd!' }
      let(:comment) { 'Some comment' }

      include_examples 'an internet password'
    end

    describe 'ascii password with backslash' do
      let(:password) { 'p4ssw\0rd!' }
      let(:comment) { nil }

      include_examples 'an internet password'
    end

    describe 'non-ascii password' do
      let(:password) { '•••p4ssw0rd!••' }
      let(:comment) { '•••Some comment•••' }

      include_examples 'an internet password'
    end
  end

  describe '#delete' do
    it 'should delete the password from the given keychain' do
      RealSecurity.with_keychain do |filename|
        expect(InternetPassword.add(server, account, 'p4ssw0rd!', keychain: filename)).to be true

        expect(InternetPassword.delete(server: server, account: account, keychain: filename)).to be true
        expect(InternetPassword.find(account: account, keychain: filename)).to be_nil
      end
    end
  end
end

describe 'when `security` is not available' do
  let(:filename) { '/nonexistent/spec.keychain-db' }
  let(:service) { 'com.example.service' }

  # Every platform other than macOS. The tool used to be reached through a
  # shell, which reported a missing command as status 127; callers depend on
  # seeing a failure rather than an exception escaping the library.
  around(:example) do |example|
    original = ENV.fetch('PATH', nil)
    ENV['PATH'] = '/nonexistent'
    begin
      example.run
    ensure
      ENV['PATH'] = original
    end
  end

  describe '#find' do
    it 'should raise a Security::Error carrying the status' do
      expect { GenericPassword.find(service: service, keychain: filename) }.to raise_error(Security::Error) do |error|
        expect(error.status).to be == 127
        expect(error.message).to match(/No such file or directory/)
      end
    end
  end

  describe '#add' do
    it 'should report failure rather than raising, relaying what went wrong' do
      expect do
        expect(GenericPassword.add(service, 'jappleseed', 'p4ssw0rd', keychain: filename)).to be false
      end.to output(/No such file or directory/).to_stderr
    end
  end

  describe '#delete' do
    it 'should report failure rather than raising' do
      expect(GenericPassword.delete(service: service, keychain: filename)).to be false
    end
  end
end
