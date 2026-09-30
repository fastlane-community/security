# frozen_string_literal: true

describe Identity do
  # The shape `security find-identity` prints.
  let(:listing) do
    <<~OUTPUT
      1) A1B2C3D4E5F60718293A4B5C6D7E8F9012345678 "Apple Development: someone (TEAM123)"
      2) 0F1E2D3C4B5A69788796A5B4C3D2E1F009876543 "Apple Distribution: someone else (TEAM123)"
         2 valid identities found
    OUTPUT
  end
  let(:found) { Security::Command::Result.new(listing, '', nil) }
  let(:none) { Security::Command::Result.new("     0 valid identities found\n", '', nil) }

  before do
    allow(found).to receive(:success?).and_return(true)
    allow(none).to receive(:success?).and_return(true)
  end

  describe '.find' do
    it 'should return one identity per listed row' do
      allow(Security::Command).to receive(:run).and_return(found)

      identities = Identity.find
      expect(identities.size).to be == 2
      expect(identities.first.sha1).to be == 'A1B2C3D4E5F60718293A4B5C6D7E8F9012345678'
      expect(identities.first.name).to be == 'Apple Development: someone (TEAM123)'
    end

    it 'should keep the status security prints after an invalid identity' do
      listing = <<~OUTPUT
        1) A1B2C3D4E5F60718293A4B5C6D7E8F9012345678 "Apple Development: someone (TEAM123)" (CSSMERR_TP_CERT_REVOKED)
        2) 0F1E2D3C4B5A69788796A5B4C3D2E1F009876543 "Apple Distribution: "quoted" (TEAM123)"
      OUTPUT
      result = Security::Command::Result.new(listing, '', nil)
      allow(result).to receive(:success?).and_return(true)
      allow(Security::Command).to receive(:run).and_return(result)

      revoked, quoted = Identity.find
      expect(revoked.name).to be == 'Apple Development: someone (TEAM123)'
      expect(revoked.status).to be == 'CSSMERR_TP_CERT_REVOKED'
      expect([quoted.name, quoted.status]).to be == ['Apple Distribution: "quoted" (TEAM123)', nil]
    end

    it 'should ask for valid identities and the codesigning policy by default' do
      expect(Security::Command).to receive(:run)
        .with('security', 'find-identity', '-v', '-p', 'codesigning').and_return(found)

      Identity.find
    end

    it 'should include the invalid ones when asked' do
      expect(Security::Command).to receive(:run)
        .with('security', 'find-identity', '-p', 'codesigning').and_return(found)

      Identity.find(valid_only: false)
    end

    it 'should search a named keychain' do
      expect(Security::Command).to receive(:run)
        .with('security', 'find-identity', '-v', '-p', 'codesigning', '/tmp/a.keychain')
        .and_return(found)

      Identity.find(keychain: Keychain.new('/tmp/a.keychain'))
    end

    it 'should return nothing rather than raising when there are none' do
      # `security` exits 0 and says so, which is not a failure.
      allow(Security::Command).to receive(:run).and_return(none)

      expect(Identity.find).to be_empty
    end

    it 'should raise when security fails' do
      failed = Security::Command::Result.new('', "unknown policy\n", nil)
      allow(failed).to receive_messages(success?: false, exitstatus: 1)
      allow(Security::Command).to receive(:run).and_return(failed)

      expect { Identity.find(policy: 'nope') }.to raise_error(Security::Error, /unknown policy/)
    end
  end
  describe '.find against the real tool' do
    it 'should return identities, or none, without raising' do
      # Whatever this machine has. The point is that the parse survives real
      # output, including the "0 valid identities found" case.
      found = Identity.find
      expect(found).to all(be_an(Identity))
      found.each do |identity|
        expect(identity.sha1).to match(/\A\h+\z/)
        expect(identity.name).not_to be_empty
      end
    end

    it 'should find none in an empty keychain' do
      RealSecurity.with_keychain do |keychain|
        expect(Identity.find(keychain: keychain)).to be_empty
      end
    end
  end
end
