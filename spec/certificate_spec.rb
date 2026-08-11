# frozen_string_literal: true

describe Certificate do
  describe '#find' do
    it 'should raise NotImplementedError' do
      expect { Certificate.find }.to raise_error(NotImplementedError)
    end
  end

  describe '#initialize' do
    it 'should raise NoMethodError' do
      expect { Certificate.new }.to raise_error(NoMethodError, /private method/)
    end
  end

  describe 'an instance' do
    subject { Certificate.send(:new) }

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
end
