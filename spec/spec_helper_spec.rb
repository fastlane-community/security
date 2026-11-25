# frozen_string_literal: true

describe RealSecurity do
  describe '.with_keychain' do
    it 'stops before running the example or deleting a keychain when creation fails' do
      failure = Security::Command::Result.new('', 'could not create keychain', nil)
      expect(Security::Command).to receive(:run)
        .with('security', 'create-keychain', '-p', '', kind_of(String)).and_return(failure)

      expect { RealSecurity.with_keychain { raise 'unexpected yield' } }.to raise_error(/could not create keychain/)
    end
  end
end
