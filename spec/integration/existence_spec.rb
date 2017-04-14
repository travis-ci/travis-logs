# frozen_string_literal: true

describe Travis::Logs::Existence do
  let(:existence) { described_class.new }

  describe '#occupied!' do
    it 'sets channel to occupied state' do
      existence.occupied!('foo')
      expect(existence.occupied?('foo')).to eq('true')

      expect(described_class.new.occupied?('foo')).to eq('true')
    end
  end

  describe '#vacant!' do
    before do
      existence.occupied!('foo')
      expect(existence.occupied?('foo')).to eq('true')
    end

    it 'sets channel to vacant state' do
      existence.vacant!('foo')
      expect(existence.occupied?('foo')).to be nil

      expect(described_class.new.occupied?('foo')).to be nil
    end
  end
end
