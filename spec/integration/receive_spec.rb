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

  it 'stores the log part in the database' do
    allow(Travis::Amqp::Consumer).to receive(:jobs) { queue }
    allow(Travis.config).to receive(:pusher_client) { double('pusher_client', :[] => double('channel', trigger: nil)) }
    db = Travis::Logs::Helpers::Database.create_sequel
    db[:logs].delete
    db[:log_parts].delete
    Travis::Logs.database_connection = Travis::Logs::Helpers::Database.connect
    Travis::Logs::Receive::Queue.subscribe('logs', Travis::Logs::Services::ProcessLogPart)
    message = double('message', ack: nil)
    queue.call(message, '{"id":123,"log":"hello, world","number":1}')
    log = db[:logs].first
    log_part = db[:log_parts].first

    expect(log[:job_id]).to eq(123)
    expect(log_part[:content]).to eq('hello, world')
    expect(log_part[:number]).to eq(1)
    expect(log_part[:final]).to be false
    expect(log_part[:log_id]).to eq(log[:id])
  end

  it 'uses the default prefetch' do
    expect(Travis::Amqp::Consumer).to receive(:jobs).with('logs', channel: { prefetch: 1 }) { queue }
    Travis::Logs::Receive::Queue.subscribe('logs', Travis::Logs::Services::ProcessLogPart)
  end

  it 'uses a custom prefetch given in the config' do
    allow(Travis.config.amqp).to receive(:prefetch) { 2 }
    expect(Travis::Amqp::Consumer).to receive(:jobs).with('logs', channel: { prefetch: 2 }) { queue }
    Travis::Logs::Receive::Queue.subscribe('logs', Travis::Logs::Services::ProcessLogPart)
  end
end
