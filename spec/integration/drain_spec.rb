# frozen_string_literal: true

class FakeAmqpQueue
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
    allow_any_instance_of(Travis::Logs::DrainQueue)
      .to receive(:jobs_queue).and_return(queue)
    allow_any_instance_of(Travis::Logs::DrainQueue)
      .to receive(:batch_size).and_return(1)
  end

  it 'passes logs queue messages to callable' do
    performed = []
    Travis::Logs::DrainQueue.subscribe('logs') { |p| performed << p }

    delivery_info = double('delivery_info', delivery_tag: 'yey')
    queue.call(delivery_info, nil, '{"id":123,"log":"hello, world","number":1}')

    expect(performed.length).to be > 0
  end
end
