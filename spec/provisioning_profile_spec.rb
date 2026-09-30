# frozen_string_literal: true

require 'tempfile'

describe ProvisioningProfile do
  let(:path) { '/tmp/a profile.mobileprovision' }
  let(:decoded) { Security::Command::Result.new("<plist/>\n", '', nil) }

  before { allow(decoded).to receive(:success?).and_return(true) }

  describe '.decode' do
    it 'should return what security printed' do
      expect(Security::Command).to receive(:run)
        .with('security', 'cms', '-D', '-i', path).and_return(decoded)

      expect(ProvisioningProfile.decode(path)).to be == "<plist/>\n"
    end

    it 'should pass the path as an argument rather than through a shell' do
      # The space is the point: nothing here escapes it, and nothing has to.
      expect(Security::Command).to receive(:run)
        .with('security', 'cms', '-D', '-i', '/tmp/a profile.mobileprovision')
        .and_return(decoded)

      ProvisioningProfile.decode(path)
    end

    describe 'with a keychain' do
      it 'should name it, so the signing certificate does not land in the default one' do
        expect(Security::Command).to receive(:run)
          .with('security', 'cms', '-D', '-i', path, '-k', '/tmp/scratch.keychain')
          .and_return(decoded)

        ProvisioningProfile.decode(path, keychain: '/tmp/scratch.keychain')
      end

      it 'should accept a Keychain as well as a filename' do
        expect(Security::Command).to receive(:run)
          .with('security', 'cms', '-D', '-i', path, '-k', '/tmp/scratch.keychain')
          .and_return(decoded)

        ProvisioningProfile.decode(path, keychain: Keychain.new('/tmp/scratch.keychain'))
      end
    end

    describe 'when security fails' do
      let(:failed) { Security::Command::Result.new('', "cms: no such file\n", nil) }

      it 'should raise with what it said' do
        allow(failed).to receive_messages(success?: false, exitstatus: 1)
        allow(Security::Command).to receive(:run).and_return(failed)

        expect { ProvisioningProfile.decode(path) }
          .to raise_error(Security::Error, /no such file/)
      end
    end
  end
  describe '.decode against the real tool' do
    let(:payload) { '<?xml version="1.0"?><plist><dict/></plist>' }

    # Every example here decodes a real blob, and decoding imports the signer.
    # If the keychain argument ever stops reaching `security`, that import goes
    # to whoever is running the suite. Checked before the tool is allowed to
    # run, so a regression fails instead of writing to their keychain.
    before do
      allow(Security::Command).to receive(:run).and_wrap_original do |original, *command|
        expect(command).to include('-k') if command.include?('cms') && @keychain
        original.call(*command)
      end
    end

    it 'should return what the blob was signed over' do
      RealSecurity.with_signed_blob(payload) do |signed|
        RealSecurity.with_keychain do |keychain|
          @keychain = keychain
          expect(ProvisioningProfile.decode(signed, keychain: keychain)).to include('<plist>')
        end
      end
    end

    it 'should put the signing certificate in the keychain it was given' do
      # The reason the argument exists. Verifying the CMS signature imports the
      # signer, and without this it goes to the user's default keychain.
      #
      # Asserted on the command rather than on the result, deliberately. Reading
      # the keychain back would mean that a regression here writes a
      # certificate into whoever ran the suite, which is the behaviour this
      # library exists to let callers avoid.
      RealSecurity.with_signed_blob(payload) do |signed|
        RealSecurity.with_keychain do |keychain|
          @keychain = keychain

          ProvisioningProfile.decode(signed, keychain: keychain)

          expect(RealSecurity.certificates_in(keychain)).to include('security gem spec')
        end
      end
    end

    it 'should raise when the file is not signed' do
      Tempfile.create('unsigned') do |file|
        file.write('not a CMS blob')
        file.flush
        expect { ProvisioningProfile.decode(file.path) }.to raise_error(Security::Error)
      end
    end
  end
end
