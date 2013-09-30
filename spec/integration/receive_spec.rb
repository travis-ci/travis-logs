require "travis/logs"
require "travis/support"
require "travis/support/amqp"
require "travis/logs/receive/queue"
require "travis/logs/services/process_log_part"
require "travis/logs/helpers/database"
require "travis/logs/helpers/reporting"

class FakeAmqpQueue
  def subscribe(opts, &block)
    @block = block
  end

  def call(*args)
    @block.call(*args)
  end
end

describe "receive_logs" do
  it "stores the log part in the database" do
    queue = FakeAmqpQueue.new
    allow(Travis::Amqp::Consumer).to receive(:jobs) { queue }
    allow(Travis.config).to receive(:pusher_client) { double("pusher_client", :[] => double("channel", trigger: nil)) }
    db = Travis::Logs::Helpers::Database.connect
    db[:logs].delete
    db[:log_parts].delete
    Travis::Logs.database_connection = db
    Travis::Logs::Services::ProcessLogPart.prepare(db)
    Travis::Logs::Receive::Queue.subscribe("logs", Travis::Logs::Services::ProcessLogPart)
    message = double("message", ack: nil)
    queue.call(message, '{"id":123,"log":"hello, world","number":1}')
    log = db[:logs].first
    log_part = db[:log_parts].first

    expect(log[:job_id]).to eq(123)
    expect(log_part[:content]).to eq("hello, world")
    expect(log_part[:number]).to eq(1)
    expect(log_part[:final]).to be_false
    expect(log_part[:log_id]).to eq(log[:id])
  end
end
