require 'travis/logs'
require 'travis/logs/existence'

describe Travis::Logs::Existence do
  subject(:existence) { described_class.new }

  describe '#occupied!' do
    it 'sets channel to occupied state' do
      existence.occupied!('foo')
      expect(existence.occupied?('foo')).to be_truthy

      # check new instance
      expect(described_class.new.occupied?('foo')).to be_truthy
    end
  end

  describe '#vacant!' do
    before do
      existence.occupied!('foo')
      expect(existence.occupied?('foo')).to be_truthy
    end

    it 'sets channel to vacant state' do
      existence.vacant!('foo')
      expect(existence.occupied?('foo')).to be_falsey

      # check new instance
      expect(described_class.new.occupied?('foo')).to be_falsey
    end
  end
end
