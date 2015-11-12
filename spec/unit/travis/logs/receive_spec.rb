require 'travis/logs/receive'

class FakeAMQPConn
  def create_channel
    self
  end

  def exchange(*)
    true
  end
end

describe Travis::Logs::Receive do
  before do
    allow(Travis::Exceptions::Reporter).to receive(:start)
    allow(Travis::Metrics).to receive(:setup)
    allow(Travis::Amqp).to receive(:connection).and_return(fake_conn)
  end

  let(:fake_conn) { FakeAMQPConn.new }

  it 'sets up all the things' do
    expect(subject.setup).to eql(:alldone)
  end
end
