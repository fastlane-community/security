# frozen_string_literal: true

require 'tempfile'

describe Certificate do
  describe '.find' do
    let(:output) do
      <<~OUTPUT
        SHA-256 hash: AA11
        SHA-1 hash: BB22
        -----BEGIN CERTIFICATE-----
        one
        -----END CERTIFICATE-----
        SHA-256 hash: CC33
        SHA-1 hash: DD44
        -----BEGIN CERTIFICATE-----
        two
        -----END CERTIFICATE-----
      OUTPUT
    end

    it 'should answer with the hashes and PEM of every match' do
      expect(Security::Command).to receive(:run)
        .with('security', 'find-certificate', '-a', '-c', 'Developer ID Installer', '-Z', '-p', '/a b.keychain')
        .and_return(Security::Command::Result.new(output, '', Security::Command.run('true').status))

      certificates = Certificate.find(name: 'Developer ID Installer', keychain: Keychain.new('/a b.keychain'))

      expect(certificates.map(&:sha1)).to be == %w[BB22 DD44]
      expect(certificates.map(&:sha256)).to be == %w[AA11 CC33]
      expect(certificates.first.pem).to be == "-----BEGIN CERTIFICATE-----\none\n-----END CERTIFICATE-----\n"
    end

    it 'should raise when the keychain cannot be searched' do
      status = instance_double(Process::Status, success?: false, exitstatus: 50)
      allow(Open3).to receive(:capture3).and_return(['', "security: not allowed\n", status])

      expect { Certificate.find(name: 'x') }.to raise_error(Security::Error, /not allowed/)
    end
  end

  describe '.find against the real tool' do
    it 'should find an imported certificate by part of its name' do
      RealSecurity.with_certificate do |cert, _key|
        RealSecurity.with_keychain do |keychain|
          Certificate.import(cert, keychain: keychain)

          found = Certificate.find(name: 'gem spec', keychain: keychain)

          expect(found.map(&:name)).to be == ['security gem spec']
          expect(found.first.pem).to be == File.read(cert)
          expect(Certificate.find(name: 'nothing like it', keychain: keychain)).to be_empty
        end
      end
    end
  end

  describe '#initialize' do
    it 'should raise NoMethodError' do
      expect { Certificate.new }.to raise_error(NoMethodError, /private method/)
    end
  end

  describe 'an instance' do
    subject { Certificate.send(:new, sha1: nil, sha256: nil, pem: nil) }

    describe '#delete!' do
      it 'should raise NotImplementedError' do
        expect { subject.delete! }.to raise_error(NotImplementedError)
      end
    end

    describe '#verified?' do
      it 'should raise NotImplementedError' do
        expect { subject.verified? }.to raise_error(NotImplementedError)
      end
    end
  end
  describe '.import' do
    let(:succeeded) { Security::Command.run('true') }

    it 'should import into the named keychain and trust the signing tools' do
      expect(Security::Command).to receive(:run).with(
        'security', 'import', '/tmp/a cert.cer', '-k', '/tmp/a.keychain',
        '-T', '/usr/bin/codesign', '-T', '/usr/bin/security',
        '-T', '/usr/bin/productbuild', '-T', '/usr/bin/productsign'
      ).and_return(succeeded)

      expect(Certificate.import('/tmp/a cert.cer', keychain: '/tmp/a.keychain')).to be true
    end

    it 'should accept a Keychain as well as a filename' do
      expect(Security::Command).to receive(:run)
        .with('security', 'import', 'c.p12', '-k', '/tmp/a.keychain', any_args)
        .and_return(succeeded)

      Certificate.import('c.p12', keychain: Keychain.new('/tmp/a.keychain'))
    end

    it 'should pass the file password and format when given' do
      expect(Security::Command).to receive(:run)
        .with('security', 'import', 'c.p12', '-k', 'k', '-P', 'secret', '-f', 'pkcs12', any_args)
        .and_return(succeeded)

      Certificate.import('c.p12', keychain: 'k', password: 'secret', format: 'pkcs12')
    end

    it 'should allow the trusted applications to be replaced' do
      expect(Security::Command).to receive(:run)
        .with('security', 'import', 'c.cer', '-k', 'k', '-T', '/usr/bin/codesign')
        .and_return(succeeded)

      Certificate.import('c.cer', keychain: 'k', trusted_applications: ['/usr/bin/codesign'])
    end
  end
  describe '.import against the real tool' do
    it 'should put the certificate in the keychain it was given' do
      RealSecurity.with_certificate do |cert, _key|
        RealSecurity.with_keychain do |keychain|
          expect(RealSecurity.certificates_in(keychain)).to be_empty

          expect(Certificate.import(cert, keychain: keychain)).to be true

          expect(RealSecurity.certificates_in(keychain)).to include('security gem spec')
        end
      end
    end

    it 'should raise DuplicateItemError for a certificate the keychain already holds' do
      RealSecurity.with_certificate do |cert, _key|
        RealSecurity.with_keychain do |keychain|
          expect(Certificate.import(cert, keychain: keychain)).to be true

          expect { Certificate.import(cert, keychain: keychain) }
            .to raise_error(Security::DuplicateItemError, /already exists/)
        end
      end
    end

    it 'should raise Error, not DuplicateItemError, for a file that is not a certificate' do
      Tempfile.create('not-a-cert') do |file|
        file.write('nonsense')
        file.flush
        RealSecurity.with_keychain do |keychain|
          expect { Certificate.import(file.path, keychain: keychain) }.to raise_error(Security::Error) do |error|
            expect(error).not_to be_a(Security::DuplicateItemError)
          end
        end
      end
    end
  end
end
