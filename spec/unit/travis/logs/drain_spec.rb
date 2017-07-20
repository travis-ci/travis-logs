# frozen_string_literal: true

class FakeConsumer
  def dead?
    false
  end

  def subscribe
    @subscribe = true
  end

  def subscribed?
    @subscribe == true
  end
end

describe Travis::Logs::Drain do
  before do
    allow(Travis::Exceptions).to receive(:setup)
    allow(Travis::Metrics).to receive(:setup)
    allow(Travis::Logs::Sidekiq).to receive(:setup)
    allow(subject).to receive(:create_consumer).and_return(FakeConsumer.new)
    allow(subject).to receive(:consumer_count).and_return(2)
    allow(subject).to receive(:loop_sleep_interval).and_return(0)
  end

  it 'has a setup class method' do
    expect { described_class.setup }.to_not raise_error
  end

  it 'runs with consumers subscribed' do
    subject.run(once: true)
    consumers = subject.send(:consumers)
    expect(consumers.size).to eq(2)
    expect(consumers.values.map(&:subscribed?).all?).to be true
  end

  it 'can create drain consumers' do
    expect(subject.send(:create_consumer)).to_not be nil
  end

  it 'handles batches via async log parts worker' do
    expect(Travis::Logs::Sidekiq::LogParts).to receive(:perform_async)
    subject.send(:handle_batch, [])
  end

  it 'forwards pusher payloads via async pusher forwarding worker' do
    expect(Travis::Logs::Sidekiq::PusherForwarding).to receive(:perform_async)
    subject.send(:forward_pusher_payload, 'log' => 'wat')
  end
end
