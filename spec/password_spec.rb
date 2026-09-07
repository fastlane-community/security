# frozen_string_literal: true

require 'tmpdir'

describe GenericPassword do
  let(:keychain) { Keychain.login_keychain } # FIXME: we should create a temporary keychain for tests

  describe '#add' do
    let(:service) { 'com.example.service' }
    let(:account) { 'jappleseed' }
    let(:password) { 'p4ssw0rd!' }
    let(:comment) { 'Some comment' }

    around(:example) do |example|
      GenericPassword.add(service, account, password, comment: comment)
      example.run
      GenericPassword.delete({ service: service, account: account })
    end

    it 'should be added to the keychain' do
      entry = GenericPassword.find({ account: account })
      expect(entry.keychain.filename).to be == keychain.filename
      expect(entry.attributes).to include({
                                            'acct' => account,
                                            'svce' => service,
                                            'icmt' => comment
                                          })
      expect(entry.password).to be == password
    end
  end

  describe '#find' do
    describe 'when no matching item exists' do
      it 'should return nil' do
        expect(GenericPassword.find(service: 'com.example.no-such-service')).to be_nil
      end
    end

    describe 'when the security command fails' do
      it 'should raise an error carrying the status and the output' do
        expect { GenericPassword.find(Z: 'bogus') }.to raise_error(Security::Error) do |error|
          expect(error.status).to be == 2
          expect(error.message).to match(/illegal option/)
        end
      end
    end
  end
end

describe InternetPassword do
  let(:keychain) { Keychain.login_keychain } # FIXME: we should create a temporary keychain for tests

  describe '#add' do
    let(:server) { 'example.com' }
    let(:account) { 'jappleseed@example.com' }

    describe 'ascii password' do
      let(:password) { 'p4ssw0rd!' }
      let(:comment) { 'Some comment' }

      around(:example) do |example|
        InternetPassword.add(server, account, password, comment: comment)
        example.run
        InternetPassword.delete({ server: server, account: account })
      end

      it 'should be added to the keychain' do
        entry = InternetPassword.find({ account: account })
        expect(entry.keychain.filename).to be == keychain.filename
        expect(entry.attributes).to include({
                                              'acct' => account,
                                              'srvr' => server,
                                              'icmt' => comment
                                            })
        expect(entry.password).to be == password
      end
    end

    describe 'ascii password with backslash' do
      let(:password) { 'p4ssw\0rd!' }

      around(:example) do |example|
        InternetPassword.add(server, account, password)
        example.run
        InternetPassword.delete({ server: server, account: account })
      end

      it 'should be added to the keychain' do
        entry = InternetPassword.find({ account: account })
        expect(entry.keychain.filename).to be == keychain.filename
        expect(entry.attributes).to include({
                                              'acct' => account,
                                              'srvr' => server
                                            })
        expect(entry.password).to be == password
      end
    end

    describe 'non-ascii password' do
      let(:password) { '•••p4ssw0rd!••' }
      let(:comment) { '•••Some comment•••' }

      around(:example) do |example|
        InternetPassword.add(server, account, password, comment: comment)
        example.run
        InternetPassword.delete({ server: server, account: account })
      end

      it 'should be added to the keychain' do
        entry = InternetPassword.find({ account: account })
        expect(entry.keychain.filename).to be == keychain.filename
        expect(entry.attributes).to include({
                                              'acct' => account,
                                              'srvr' => server,
                                              'icmt' => comment
                                            })
        expect(entry.password).to be == password
      end
    end
  end
end

describe 'a non-default keychain' do
  # `security` reports the resolved path, and Dir.tmpdir is a symlink on macOS
  let(:filename) { File.join(File.realpath(Dir.tmpdir), 'security-spec.keychain-db') }
  let(:keychain) { Keychain.new(filename) }
  let(:service) { 'com.example.service' }
  let(:account) { 'jappleseed' }
  let(:password) { 'p4ssw0rd!' }

  around(:example) do |example|
    Security::Command.run("security create-keychain -p spec-password #{filename.shellescape}")
    example.run
    Security::Command.run("security delete-keychain #{filename.shellescape}")
  end

  describe '#add' do
    it 'should add the password to the given keychain' do
      expect(GenericPassword.add(service, account, password, keychain: filename)).to be true

      entry = GenericPassword.find(service: service, keychain: filename)
      expect(entry.keychain.filename).to be == filename
      expect(entry.password).to be == password
    end

    it 'should not add the password to the default keychain' do
      GenericPassword.add(service, account, password, keychain: filename)

      expect(GenericPassword.find(service: service)).to be_nil
    end
  end

  describe '#delete' do
    it 'should delete the password from the given keychain' do
      GenericPassword.add(service, account, password, keychain: filename)

      expect(GenericPassword.delete(service: service, keychain: filename)).to be true
      expect(GenericPassword.find(service: service, keychain: filename)).to be_nil
    end
  end

  describe 'when given a Keychain' do
    it 'should act on the keychain it names' do
      GenericPassword.add(service, account, password, keychain: keychain)

      entry = GenericPassword.find(service: service, keychain: keychain)
      expect(entry.keychain.filename).to be == filename
      expect(entry.password).to be == password
    end
  end
end
