# frozen_string_literal: true

require 'tempfile'

describe Keychain do
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
      expect(Keychain).to receive(:system).with('security lock-keychain -a')
      Keychain.lock
    end
  end

  describe '#unlock' do
    it 'should unlock keychains with the given password' do
      expect(Keychain).to receive(:system).with('security unlock-keychain -p p4ssw0rd')
      Keychain.unlock('p4ssw0rd')
    end
  end

  describe 'an instance' do
    subject { Keychain.new('test.keychain-db') }

    describe '#info' do
      it 'should show keychain info' do
        expect(subject).to receive(:system).with('security show-keychain-info test.keychain-db')
        subject.info
      end
    end

    describe '#lock' do
      it 'should lock the keychain' do
        expect(subject).to receive(:system).with('security lock-keychain test.keychain-db')
        subject.lock
      end
    end

    describe '#unlock' do
      it 'should unlock the keychain with the given password' do
        expect(subject).to receive(:system).with('security unlock-keychain -p p4ssw0rd test.keychain-db')
        subject.unlock('p4ssw0rd')
      end
    end

    describe '#delete' do
      it 'should delete the keychain' do
        expect(subject).to receive(:system).with('security delete-keychain test.keychain-db')
        subject.delete
      end
    end
  end

  describe '#create' do
    let(:password) { 'p4ssw0rd!' }

    it 'should raise NotImplementedError' do
      Tempfile.open('example.keychain-db') do |tmp|
        expect { Keychain.create(tmp.path, password) }.to raise_error(NotImplementedError)
      end
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
      it 'should raise an error' do
        expect { Keychain.list(:invalid) }.to raise_error(NoMethodError) # FIXME
      end
    end
  end
end
