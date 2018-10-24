# frozen_string_literal: true

describe Travis::Logs::Sidekiq::ErrorMiddleware do
  subject do
    described_class.new(pause_time: 0)
  end

  it 'calls the block it wraps' do
    state = { foo: 1 }
    subject.call('worky', 'flah', 'qbert') do
      state[:foo] = 0
    end
    expect(state[:foo]).to eq 0
  end

  it 'does not handle unknown errors' do
    expect do
      subject.call('worky', 'flah', 'booms') do
        raise StandardError, ':boom:'
      end
    end.to raise_error(StandardError)
  end

  it 'retries maintenance errors' do
    expect do
      state = { times: 0 }
      subject.call('worky', 'flah', 'booms') do
        state[:times] += 1
        raise ArgumentError, ':boom:' if state[:times] > 1

        raise Travis::Logs::UnderMaintenanceError, 0.01
      end
    end.to raise_error(ArgumentError)
  end
end
