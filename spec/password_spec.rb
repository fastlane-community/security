require_relative '../lib/security'
include Security

describe GenericPassword do
  let(:keychain) { Keychain.login_keychain } # FIXME: we should create a temporary keychain for tests

  describe '#add' do
    let(:service) { 'com.example.service' }
    let(:account) { 'jappleseed' }
    let(:password) { 'p4ssw0rd!' }

    around(:example) do |example|
      GenericPassword.add(service, account, password)
      example.run
      GenericPassword.delete({ service: service, account: account })
    end

    it 'should be added to the keychain' do
      entry = GenericPassword.find({ account: account })
      expect(entry.keychain.filename).to be == keychain.filename
      expect(entry.attributes).to include({
                                            'acct' => account,
                                            'svce' => service
                                          })
      expect(entry.password).to be == password
    end
  end
end

describe InternetPassword do
  let(:keychain) { Keychain.login_keychain } # FIXME: we should create a temporary keychain for tests

  describe '#add' do
    let(:server) { 'example.com' }
    let(:account) { 'jappleseed@example.com' }
    let(:password) { 'p4ssw0rd!' }

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
end
