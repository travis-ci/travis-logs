require 'spec_helper'
require 'travis/logs/receive'

describe Travis::Logs::Receive do
  let(:app)     { described_class.new }
  let(:payload) { { 'id' => 1, 'log' => 'foo' } }

  before :each do
    Travis.config.logs.stubs(:shards).returns(3)
  end

  describe 'run' do
    let(:consumer) { stub('consumer', :subscribe => nil) }

    before :each do
      Travis::Amqp::Consumer.stubs(:jobs).returns(consumer)
    end

    it 'subscribes to reporting.jobs.logs' do
      Travis::Amqp::Consumer.expects(:jobs).with('logs').returns(consumer)
      app.run
    end

    it 'subscribes to reporting.jobs.logs.[shard] for n shards' do
      0.upto(2) do |shard|
        Travis::Amqp::Consumer.expects(:jobs).with("logs.#{shard}").returns(consumer)
      end
      app.run
    end

    describe 'with queue_number present' do
      it 'adds queue_number to queue_name' do
        app.stubs(:number).returns(6)

        Travis::Amqp::Consumer.expects(:jobs).with('logs6').returns(consumer)
        0.upto(2) do |shard|
          Travis::Amqp::Consumer.expects(:jobs).with("logs6.#{shard}").returns(consumer)
        end

        app.run
      end
    end
  end

  describe 'route' do
    let(:publisher) { stub('publisher', :publish => nil) }

    before :each do
      Travis::Amqp::Publisher.stubs(:jobs).returns(publisher)
    end

    it 're-routes the message to reporting.jobs.logs.[shard]' do
      Travis::Amqp::Publisher.expects(:jobs).with('logs.1').returns(publisher)
      app.send(:route, payload)
    end

    it 're-routes the message with the original payload' do
      publisher.expects(:publish).with(payload.merge(uuid: Travis.uuid))
      app.send(:route, payload)
    end
  end

  describe 'receive' do
    it 'handles the log update' do
      Travis.expects(:run_service).with(:logs_append, data: { 'id' => 1, 'log' => 'foo' })
      app.send(:receive, payload)
    end
  end
end
