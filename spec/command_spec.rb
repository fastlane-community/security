# frozen_string_literal: true

describe Security::Command do
  describe '.run' do
    describe 'when the command succeeds' do
      subject { Security::Command.run('echo out; echo err 1>&2') }

      it 'should capture both streams and the status' do
        expect(subject.stdout).to be == "out\n"
        expect(subject.stderr).to be == "err\n"
        expect(subject.exitstatus).to be_zero
        expect(subject.success?).to be true
        expect(subject.output).to be == "out\nerr\n"
      end
    end

    describe 'when the command fails' do
      subject { Security::Command.run('exit 3') }

      it 'should report the status' do
        expect(subject.exitstatus).to be == 3
        expect(subject.success?).to be false
      end
    end

    it 'should not relay what the command printed' do
      expect { Security::Command.run('echo quiet 1>&2') }.not_to output.to_stderr
    end
  end

  describe '.run when the command does not exist' do
    subject { Security::Command.run('security-does-not-exist') }

    it 'should report a failure rather than raising' do
      expect(subject.success?).to be false
      expect(subject.stderr).to match(/No such file or directory/)
    end

    it 'should report the status a shell gives a missing command' do
      expect(subject.exitstatus).to be == 127
    end
  end

  describe 'a result for a command that never ran' do
    subject { Security::Command::Result.new('', '', nil) }

    it 'should not be a success' do
      expect(subject.success?).to be false
      expect(subject.exitstatus).to be_nil
    end
  end

  describe '.relay' do
    it 'should relay what the command printed and return the result' do
      result = nil
      expect { result = Security::Command.relay('echo boom 1>&2; exit 1') }.to output("boom\n").to_stderr
      expect(result.success?).to be false
    end

    it 'should stay silent when the command printed nothing' do
      expect { Security::Command.relay('true') }.not_to output.to_stderr
    end
  end
end
