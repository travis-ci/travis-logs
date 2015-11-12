require 'travis/logs/receive/queue'

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
end
