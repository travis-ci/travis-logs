require 'travis/logs/receive/queue'

class FakeMarkable
  def mark
    :marked
  end
end

class FakeErrorLogger
  attr_reader :errors

  def initialize
    @errors = []
  end

  def error(message)
    @errors << message
  end
end

class FakeDeliveryInfo
  def delivery_tag
    'whatebber'
  end
end

describe Travis::Logs::Receive::Queue do
  subject { described_class.new('test', handler) }

  let(:handler) { double('handler') }
  let(:message) { double('message') }
  let(:delivery_info) { FakeDeliveryInfo.new }
  let(:channel) { double('channel') }

  context 'when handler#run explodes' do
    before do
      subject.instance_variable_set(:@channel, channel)
      allow(handler).to receive(:run).and_raise(StandardError)
      allow(channel).to receive(:reject)
    end

    it 'logs the exception' do
      expect(subject).to receive(:log_exception)
      subject.send(:receive, delivery_info, message, pay: :load, 'uuid' => 'foo')
    end
  end

  context 'when a block given to #smart_retry repeatedly times out' do
    before do
      allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
      allow(Metriks).to receive(:meter).and_return(FakeMarkable.new)
    end

    it 're-raises the error' do
      expect do
        subject.send(:smart_retry, &:puts)
      end.to raise_error(Timeout::Error)
    end
  end

  context 'when decoding explodes with StandardError descendant' do
    before do
      allow(Metriks).to receive(:meter).and_return(FakeMarkable.new)
    end

    it 'rescues and returns nil' do
      expect(subject.send(:decode, '{.')).to eql(nil)
    end
  end

  context 'when Travis::Exceptions.handle explodes' do
    before do
      allow(Travis::Exceptions).to receive(:handle)
        .and_raise(Exception.new('boom'))
      allow(Travis).to receive(:logger).and_return(logger)
    end

    let(:logger) { FakeErrorLogger.new }

    it 'logs a failsafe message' do
      subject.send(:log_exception, :tofurkey, pay: :load)
      expect(logger.errors).to include('!!!FAILSAFE!!! boom')
    end
  end
end
