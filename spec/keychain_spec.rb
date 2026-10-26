# frozen_string_literal: true

describe Keychain do
  let(:succeeded) { Security::Command.run('true') }

  describe '#login_keychain' do
    subject { Keychain.login_keychain }

    it 'should be located in the user home directory' do
      expect(subject.filename).to be == File.expand_path('~/Library/Keychains/login.keychain-db')
    end
  end

  describe '#default_keychain' do
    subject { Keychain.default_keychain }

    it 'should return a keychain' do
      expect(subject).to be_a(Keychain)
      expect(subject.filename).not_to be_empty
    end
  end

  describe '#lock' do
    it 'should lock all keychains' do
      expect(Security::Command).to receive(:relay)
        .with('security', 'lock-keychain', '-a').and_return(succeeded)
      Keychain.lock
    end
  end

  describe '#unlock' do
    it 'should unlock keychains with the given password' do
      expect(Security::Command).to receive(:relay)
        .with('security', 'unlock-keychain', '-p', 'p4ssw0rd').and_return(succeeded)
      Keychain.unlock('p4ssw0rd')
    end
  end

  describe 'an instance' do
    subject { Keychain.new('test.keychain-db') }

    describe '#info' do
      it 'should show keychain info' do
        expect(Security::Command).to receive(:relay)
          .with('security', 'show-keychain-info', 'test.keychain-db').and_return(succeeded)
        subject.info
      end
    end

    describe '#lock' do
      it 'should lock the keychain' do
        expect(Security::Command).to receive(:relay)
          .with('security', 'lock-keychain', 'test.keychain-db').and_return(succeeded)
        subject.lock
      end
    end

    describe '#unlock' do
      it 'should unlock the keychain with the given password' do
        expect(Security::Command).to receive(:relay)
          .with('security', 'unlock-keychain', '-p', 'p4ssw0rd', 'test.keychain-db').and_return(succeeded)
        subject.unlock('p4ssw0rd')
      end
    end

    describe '#delete' do
      it 'should delete the keychain' do
        expect(Security::Command).to receive(:relay)
          .with('security', 'delete-keychain', 'test.keychain-db').and_return(succeeded)
        subject.delete
      end
    end
  end

  describe 'an instance, changing settings' do
    subject { Keychain.new('a b.keychain-db') }

    it 'should never lock when given no options' do
      expect(Security::Command).to receive(:relay)
        .with('security', 'set-keychain-settings', 'a b.keychain-db').and_return(succeeded)
      expect(subject.update_settings).to be true
    end

    it 'should pass the timeout and the lock flags' do
      expect(Security::Command).to receive(:relay)
        .with('security', 'set-keychain-settings', '-t', '300', '-l', '-u', 'a b.keychain-db').and_return(succeeded)
      subject.update_settings(timeout: 300, lock_when_sleeping: true, lock_after_timeout: true)
    end
  end

  describe '#set_key_partition_list' do
    subject { Keychain.new('a b.keychain-db') }

    it 'should allow the signing tools by default' do
      expect(Security::Command).to receive(:run)
        .with('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s',
              '-k', 'p4ss word', 'a b.keychain-db').and_return(succeeded)
      expect(subject.set_key_partition_list('p4ss word')).to be true
    end

    it 'should raise with the output when the password is wrong' do
      status = instance_double(Process::Status, success?: false, exitstatus: 1)
      allow(Open3).to receive(:capture3).and_return(['', "SecKeychainItemSetAccessWithPassword: wrong\n", status])

      expect { subject.set_key_partition_list('nope') }
        .to raise_error(Security::Error, /SecKeychainItemSetAccessWithPassword/)
    end
  end

  describe '#set_key_partition_list against the real tool' do
    # Only the success: macOS 15 accepts a wrong password here and macOS 26 rejects it,
    # so that path is covered by the stubbed example above.
    it 'should succeed with the keychain password' do
      RealSecurity.with_identity('p12') do |identity|
        RealSecurity.with_keychain do |path|
          Certificate.import(identity, keychain: path, password: 'p12')

          expect(Keychain.new(path).set_key_partition_list('')).to be true
        end
      end
    end
  end

  describe '#create' do
    it 'should create a keychain and answer with it' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'a b.keychain-db')
        keychain = Keychain.create(path, 'p4ss word')
        begin
          expect(keychain.filename).to be == path
          expect(File.exist?(path)).to be true
          expect(keychain.unlock('p4ss word')).to be true
        ensure
          keychain.delete
        end
      end
    end

    it 'should raise when the keychain cannot be created' do
      expect { Keychain.create('/nonexistent/dir/a.keychain-db', 'p') }.to raise_error(Security::Error)
    end
  end

  describe '#set_search_list' do
    it 'should set the search list of the user domain from keychains or filenames' do
      expect(Security::Command).to receive(:relay)
        .with('security', 'list-keychains', '-d', 'user', '-s', '/a.keychain-db', '/b c.keychain-db')
        .and_return(succeeded)
      Keychain.set_search_list([Keychain.new('/a.keychain-db'), '/b c.keychain-db'])
    end

    it 'should reject an unknown domain' do
      expect { Keychain.set_search_list([], domain: :nope) }.to raise_error(ArgumentError)
    end
  end

  describe '#set_default_keychain' do
    it 'should set the default keychain of the user domain' do
      expect(Security::Command).to receive(:relay)
        .with('security', 'default-keychain', '-d', 'user', '-s', '/a b.keychain-db').and_return(succeeded)
      expect(Keychain.set_default_keychain('/a b.keychain-db')).to be true
    end
  end

  describe '#supports_key_partition_list?' do
    it 'should read the subcommands security lists' do
      expect(Keychain.supports_key_partition_list?).to be true
    end

    it 'should be false when security does not list it' do
      help = Security::Command::Result.new("list-keychains\n", '', nil)
      allow(Security::Command).to receive(:run).with('security', '-h').and_return(help)
      expect(Keychain.supports_key_partition_list?).to be false
    end
  end

  describe '#list' do
    describe 'when passing no arguments' do
      it 'should list keychains in user domain' do
        expect(Keychain.list).to satisfy { |keychains|
          keychains.map(&:filename) == Keychain.list(:user).map(&:filename)
        }
      end
    end

    describe 'when passing a valid domain' do
      it 'should not raise an error' do
        expect { Keychain.list(:user) }.not_to raise_error
        expect { Keychain.list(:system) }.not_to raise_error
        expect { Keychain.list(:common) }.not_to raise_error
        expect { Keychain.list(:dynamic) }.not_to raise_error
      end
    end

    describe 'when passing an invalid domain' do
      it 'should raise an error naming the valid domains' do
        expect { Keychain.list(:invalid) }.to raise_error(
          ArgumentError, 'Invalid domain invalid, expected one of: [:user, :system, :common, :dynamic]'
        )
      end
    end

    describe 'when the security command fails' do
      it 'should raise an error carrying the status and the output' do
        status = instance_double(Process::Status, success?: false, exitstatus: 1)
        allow(Open3).to receive(:capture3).and_return(['', "security: unknown command\n", status])

        expect { Keychain.list }.to raise_error(Security::Error) do |error|
          expect(error.status).to be == 1
          expect(error.message).to match(/unknown command/)
        end
      end
    end
  end
end
