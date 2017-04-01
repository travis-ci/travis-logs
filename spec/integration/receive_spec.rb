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
    allow(Travis::Logs::Helpers::Pusher).to receive(:new).and_return(
      double(
        'pusher_client',
        :[] => double('channel', trigger: nil),
        push: nil,
        pusher_channel_name: 'channel'
      )
    )
  end

  it 'stores the log part in the database' do
    allow_any_instance_of(Travis::Logs::Receive::Queue)
      .to receive(:jobs_queue) { queue }
    database = Travis::Logs::Helpers::Database.new
    database.connect
    db = database.send(:db)
    db[:logs].delete
    db[:log_parts].delete
    Travis::Logs.database_connection = database
    Travis::Logs::Receive::Queue.subscribe(
      'logs', Travis::Logs::Services::ProcessLogPart.new
    )
    delivery_info = double('delivery_info', delivery_tag: 'yey')
    queue.call(delivery_info, nil, '{"id":123,"log":"hello, world","number":1}')
    log = db[:logs].first
    log_part = db[:log_parts].first

    expect(log[:job_id]).to eq(123)
    expect(log_part[:content]).to eq('hello, world')
    expect(log_part[:number]).to eq(1)
    expect(log_part[:final]).to be false
    expect(log_part[:log_id]).to eq(log[:id])
  end
end
