# frozen_string_literal: true

describe Travis::Logs::Config do
  it 'wraps and augments #amqp' do
    expect(subject.amqp).to include(:properties)
  end

  it 'provides a process name' do
    expect(subject.process_name).to eq('logs.test.anon')
  end
end
