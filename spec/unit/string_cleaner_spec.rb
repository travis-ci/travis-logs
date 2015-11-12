require 'string_cleaner'

describe StringCleaner do
  it 'initializes with no bytes' do
    expect(subject.bytes).to be_empty
  end

  it 'cleans without mutation' do
    dirty = "\x00\x00\x00\x00zzzz"
    expect(described_class.clean(dirty).object_id).to_not eql(dirty.object_id)
  end

  it 'cleans with mutation' do
    dirty = "\x00\x00\x00\x00zzzz"
    expect(described_class.clean!(dirty).object_id).to eql(dirty.object_id)
  end

  it 'cleans while appending string' do
    cleaner = StringCleaner.new
    dirty = "\x00\x00\x00\x00zzzz"
    cleaner << dirty
    expect(cleaner.to_s).to_not include(dirty)
  end

  it 'cleans while appending array' do
    cleaner = StringCleaner.new
    dirty = ["\x00", "\x00", "\x00", "\x00", 'z', 'z', 'z', 'z']
    cleaner << dirty
    expect(cleaner.to_s).to_not include("\x00")
  end

  it 'cleans while appending bytecodes' do
    cleaner = StringCleaner.new
    (001..253).each do |ord|
      cleaner << ord
    end
    expect(cleaner.to_s).to_not include("\x00")
  end
end
