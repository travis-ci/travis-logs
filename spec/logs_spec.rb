require 'spec_helper'

describe Travis::Logs do
  let(:app)     { Travis::Logs::App.new }
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
      app.send(:subscribe)
    end

    it 'subscribes to reporting.jobs.logs.[shard] for n shards' do
      0.upto(2) do |shard|
        Travis::Amqp::Consumer.expects(:jobs).with("logs.#{shard}").returns(consumer)
      end
      app.send(:subscribe)
    end

    describe 'with queue_number present' do
      it 'adds queue_number to queue_name' do
        Travis::Logs.stubs :queue_number => 6

        Travis::Amqp::Consumer.expects(:jobs).with('logs6').returns(consumer)
        0.upto(2) do |shard|
          Travis::Amqp::Consumer.expects(:jobs).with("logs6.#{shard}").returns(consumer)
        end

        app.send(:subscribe)
      end
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
        app.send(:receive, :route, message, payload)
      end

      it 're-routes the message with the original payload' do
        publisher.expects(:publish).with(MultiJson.decode(payload))
        app.send(:receive, :route, message, payload)
      end
    end

    describe 'from reporting.jobs.logs.0' do
      before :each do
        Job::Test.stubs(:append_log!)
      end

      it 'handles the log update' do
        Travis.expects(:run_service).with(:logs_append, data: { 'id' => 1, 'log' => 'foo' })
        app.send(:receive, :log, message, payload)
      end
    end
  end
end
