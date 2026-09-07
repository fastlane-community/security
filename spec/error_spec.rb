# frozen_string_literal: true

describe Security::Error do
  describe '#initialize' do
    describe 'when the command produced output' do
      subject { Security::Error.new(2, "security: something went wrong\n") }

      it 'should report the output and the status' do
        expect(subject.status).to be == 2
        expect(subject.output).to be == "security: something went wrong\n"
        expect(subject.message).to be == 'security: something went wrong (status 2)'
      end
    end

    describe 'when the command produced no output' do
      subject { Security::Error.new(36, '') }

      it 'should report the status' do
        expect(subject.status).to be == 36
        expect(subject.message).to be == '`security` exited with status 36'
      end
    end
  end
end
