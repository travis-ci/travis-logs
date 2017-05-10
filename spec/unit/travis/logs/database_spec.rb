# frozen_string_literal: true

describe Travis::Logs::Database do
  it 'determines statement_timeout' do
    expect(described_class.send(:statement_timeout_ms)).to_not be_nil
    expect(described_class.send(:statement_timeout_ms)).to be_positive
    expect(described_class.send(:statement_timeout_ms)).to be < 30 * 60 * 1_001
    expect(described_class.send(:statement_timeout_ms)).to be > 29 * 1_000
  end
end
