# frozen_string_literal: true

require 'tempfile'

describe Security::Command do
  describe '.run' do
    describe 'when the command succeeds' do
      subject { Security::Command.run('sh', '-c', 'echo out; echo err 1>&2') }

      it 'should capture both streams and the status' do
        expect(subject.stdout).to be == "out\n"
        expect(subject.stderr).to be == "err\n"
        expect(subject.exitstatus).to be_zero
        expect(subject.success?).to be true
        expect(subject.output).to be == "out\nerr\n"
      end
    end

    describe 'when the command fails' do
      subject { Security::Command.run('sh', '-c', 'exit 3') }

      it 'should report the status' do
        expect(subject.exitstatus).to be == 3
        expect(subject.success?).to be false
      end
    end

    it 'should not relay what the command printed' do
      expect { Security::Command.run('sh', '-c', 'echo quiet 1>&2') }.not_to output.to_stderr
    end
  end

  describe '.run' do
    it 'should not hand a lone command line to a shell' do
      result = Security::Command.run('echo one && echo two')
      expect(result.success?).to be false
      expect(result.exitstatus).to be == 127
    end

    it 'should not go through a shell' do
      # A shell would treat these as two commands. Passed as arguments they are
      # what echo was given.
      result = Security::Command.run('echo', 'one && echo two')
      expect(result.stdout).to be == "one && echo two\n"
    end

    it 'should need no escaping for a path containing a space' do
      Tempfile.create(['a b', '.txt']) do |file|
        file.write('contents')
        file.flush
        expect(Security::Command.run('cat', file.path).stdout).to be == 'contents'
      end
    end

    it 'should report a missing command the same way' do
      result = Security::Command.run('security-does-not-exist', 'argument')
      expect(result.success?).to be false
      expect(result.exitstatus).to be == 127
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
      expect { result = Security::Command.relay('sh', '-c', 'echo boom 1>&2; exit 1') }.to output("boom\n").to_stderr
      expect(result.success?).to be false
    end

    it 'should stay silent when the command printed nothing' do
      expect { Security::Command.relay('true') }.not_to output.to_stderr
    end
  end
end
