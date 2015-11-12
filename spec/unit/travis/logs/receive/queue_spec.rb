require 'travis/logs/receive/queue'

class FakeMarkable
  def mark
    :marked
  end
end

describe Travis::Logs::Receive::Queue do
  subject { described_class.new('test', handler) }

  let(:handler) { double('handler') }
  let(:message) { double('message') }

  context 'when handler#run explodes' do
    before do
      allow(handler).to receive(:run).and_raise(StandardError)
      allow(message).to receive(:reject)
    end

    it 'logs the exception' do
      expect(subject).to receive(:log_exception)
      subject.send(:receive, message, { pay: :load, 'uuid' => 'foo' })
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
end
