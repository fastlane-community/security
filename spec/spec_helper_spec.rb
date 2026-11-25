# frozen_string_literal: true

describe RealSecurity do
  describe '.with_keychain' do
    it 'stops before running the example or deleting a keychain when creation fails' do
      failure = Security::Command::Result.new('', 'could not create keychain', nil)
      expect(Security::Command).to receive(:run)
        .with('security', 'create-keychain', '-p', '', kind_of(String)).and_return(failure)

      expect { RealSecurity.with_keychain { raise 'unexpected yield' } }.to raise_error(/could not create keychain/)
    end

    it 'reports a failure to delete the keychain after the example' do
      success = instance_double(Security::Command::Result, success?: true)
      failure = Security::Command::Result.new('', 'could not delete keychain', nil)
      expect(Security::Command).to receive(:run)
        .with('security', 'create-keychain', '-p', '', kind_of(String)).and_return(success)

      expect do
        RealSecurity.with_keychain do |path|
          expect(Security::Command).to receive(:run).with('security', 'delete-keychain', path).and_return(failure)
        end
      end.to raise_error(/could not delete keychain/)
    end
  end
end
