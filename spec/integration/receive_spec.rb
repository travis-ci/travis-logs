require 'travis/logs'
require 'travis/support'
require 'travis/support/amqp'
require 'travis/logs/receive/queue'
require 'travis/logs/services/process_log_part'
require 'travis/logs/helpers/database'

describe 'receive_logs', integration: true do
  before do
    rec = Travis::Logs::Receive.new
    Travis::Amqp.config = rec.amqp_config
    Travis.config.pusher_client = double(
      'pusher_client',
      :[] => double('channel', trigger: nil)
    )
    db[:logs].delete
    db[:log_parts].delete
    Travis::Logs.database_connection = Travis::Logs::Helpers::Database.connect
  end

  let(:db) { Travis::Logs::Helpers::Database.create_sequel }
  let(:message) { double('message') }

  it 'stores the log part in the database' do
    queue = Travis::Logs::Receive::Queue.new('logs', Travis::Logs::Services::ProcessLogPart)
    queue.subscribe

    ex = queue.send(:exchange)
    ex.publish(
      JSON.dump(id: 123, log: 'hello, world', number: 1),
      routing_key: 'reporting.jobs.logs'
    )

    log = nil
    times = 0

    loop do
      break if times > 4
      log = db[:logs].first
      break unless log.nil?
      sleep 0.2
      times += 1
    end

    log = db[:logs].first
    log_part = db[:log_parts].first

    expect(log[:job_id]).to eq(123)
    expect(log_part[:content]).to eq('hello, world')
    expect(log_part[:number]).to eq(1)
    expect(log_part[:final]).to be_falsey
    expect(log_part[:log_id]).to eq(log[:id])
  end

  it 'uses the default prefetch' do
    Travis::Logs::Receive::Queue.subscribe('logs', Travis::Logs::Services::ProcessLogPart)
  end

  it 'uses a custom prefetch given in the config' do
    Travis.config.amqp.prefetch = 2
    Travis::Logs::Receive::Queue.subscribe('logs', Travis::Logs::Services::ProcessLogPart)
  end
end
