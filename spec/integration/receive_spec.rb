# frozen_string_literal: true

require 'travis/logs'
require 'travis/support'
require 'travis/support/amqp'
require 'travis/logs/receive/queue'
require 'travis/logs/services/process_log_part'
require 'travis/logs/helpers/database'

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
    allow_any_instance_of(Travis::Logs::Receive::Queue)
      .to receive(:jobs_queue) { queue }
  end

  it 'passes logs queue messages to callable' do
    performed = []
    Travis::Logs::Receive::Queue.subscribe(
      'logs', ->(p) { performed << p }
    )

    delivery_info = double('delivery_info', delivery_tag: 'yey')
    queue.call(delivery_info, nil, '{"id":123,"log":"hello, world","number":1}')

    expect(performed.length).to eq 1
  end
end
