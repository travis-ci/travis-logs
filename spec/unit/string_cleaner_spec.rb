require 'string_cleaner'

describe StringCleaner do
  it 'initializes with no bytes' do
    expect(subject.bytes).to be_empty
  end
end
