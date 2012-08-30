require 'spec_helper'

describe Travis::Logs do
  let(:logs)    { Travis::Logs.new }
  let(:payload) { '{ "data": { "id": 1, "log": "foo" }, "uuid": "2d931510-d99f-494a-8c67-87feb05e1594" }' }
  let(:message) { stub('message', :ack => nil) }

  before :each do
    Travis.config.logs.stubs(:shards).returns(3)
  end

  describe 'subscribe' do
    let(:consumer) { stub('consumer', :subscribe => nil) }

    before :each do
      Travis::Amqp::Consumer.stubs(:jobs).returns(consumer)
    end

    it 'subscribes to reporting.jobs.logs' do
      Travis::Amqp::Consumer.expects(:jobs).with('logs').returns(consumer)
      logs.subscribe
    end

    it 'subscribes to reporting.jobs.logs.[shard] for n shards' do
      0.upto(2) do |shard|
        Travis::Amqp::Consumer.expects(:jobs).with("logs.#{shard}").returns(consumer)
      end
      logs.subscribe
    end
  end

  describe 'receive' do
    describe 'from reporting.jobs.logs' do
      let(:publisher) { stub('publisher', :publish => nil) }

      before :each do
        Travis::Amqp::Publisher.stubs(:jobs).returns(publisher)
      end

      it 're-routes the message to reporting.jobs.logs.[shard]' do
        Travis::Amqp::Publisher.expects(:jobs).with('logs.1').returns(publisher)
        logs.receive(:route, message, payload)
      end

      it 're-routes the message with the original payload' do
        publisher.expects(:publish).with(MultiJson.decode(payload))
        logs.receive(:route, message, payload)
      end
    end

    describe 'from reporting.jobs.logs.0' do
      before :each do
        Job::Test.stubs(:append_log!)
      end

      it 'handles the log update' do
        Job::Test.expects(:append_log!).with(1, 'foo')
        logs.receive(:log, message, payload)
      end
    end
  end
end
