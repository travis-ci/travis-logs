# frozen_string_literal: true

require 'travis/logs/helpers/database'

describe Travis::Logs::Helpers::Database do
  it 'builds an application_name' do
    expect(described_class.send(:application_name)).to_not be_nil
    expect(described_class.send(:application_name)).to_not be_empty
    expect(described_class.send(:application_name)).to eq 'logs.test'
  end

  it 'determines statement_timeout' do
    expect(described_class.send(:statement_timeout_ms)).to_not be_nil
    expect(described_class.send(:statement_timeout_ms)).to be_positive
    expect(described_class.send(:statement_timeout_ms)).to be < 30 * 60 * 1_001
    expect(described_class.send(:statement_timeout_ms)).to be > 29 * 1_000
  end
end
