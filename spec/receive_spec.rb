require 'spec_helper'
require 'travis/logs/receive'

describe Travis::Logs::Receive do
  let(:app)     { described_class.new }
  let(:payload) { { 'id' => 1, 'log' => 'foo', 'number' => 1, 'final' => false } }

  before :each do
    Travis.config.logs.stubs(:threads).returns(5)
  end

  describe 'run' do
    let(:consumer) { stub('consumer', :subscribe => nil) }

    before :each do
      Travis::Amqp::Consumer.stubs(:jobs).returns(consumer)
    end

    it 'subscribes to reporting.jobs.logs' do
      Travis::Amqp::Consumer.expects(:jobs).with('logs').times(5).returns(consumer)
      app.run
    end
  end

  describe 'receive' do
    it 'handles the log update' do
      Travis.expects(:run_service).with(:logs_receive, data: payload)
      app.receive(payload)
    end
  end
end
