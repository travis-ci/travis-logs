# frozen_string_literal: true

class FakeAmqpQueue
  attr_reader :name

  def subscribe(_opts, &block)
    @block = block
  end

  def call(*args)
    @block.call(*args)
  end
end

describe 'receive_logs' do
  let(:queue) { FakeAmqpQueue.new }

  before do
    allow_any_instance_of(Travis::Logs::DrainConsumer)
      .to receive(:jobs_queue).and_return(queue)
    allow_any_instance_of(Travis::Logs::DrainConsumer)
      .to receive(:batch_size).and_return(1)
  end

  it 'passes logs queue messages to callable' do
    batches = []
    pusher_payloads = []

    dq = Travis::Logs::DrainConsumer.new(
      batch_handler: ->(b) { batches << b },
      pusher_handler: ->(p) { pusher_payloads << p }
    )
    dq.subscribe

    delivery_info = double('delivery_info', delivery_tag: 'yey', to_hash: {})
    properties = Bunny::MessageProperties.new({})
    queue.call(delivery_info, properties, '{"id":123,"log":"hello, world","number":1}')

    expect(batches.length).to be > 0
    expect(pusher_payloads.length).to be > 0
  end
end
