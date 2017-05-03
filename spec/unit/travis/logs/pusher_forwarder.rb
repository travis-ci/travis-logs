# frozen_string_literal: true

describe Travis::Logs::PusherForwarder do
  let(:payload) { [{ 'id' => 2, 'log' => 'hello, world', 'number' => 1 }] }

  subject(:service) do
    described_class.new
  end

  before(:each) do
    Travis.config.channels_existence_check = true
    Travis.config.channels_existence_metrics = true
    Travis::Logs.cache.clear
    allow(Metriks).to receive(:meter).and_return(double('meter', mark: nil))
    allow(service).to receive(:channel_occupied?) { true }
    allow(service).to receive(:channel_name) { 'channel' }
  end

  describe 'existence check' do
    xit 'sends a part if channel is not occupied but the existence check is disabled' do
      expect(service).to receive(:existence_check?) { false }
      expect(service).to receive(:channel_occupied?) { false }
      expect(service).to receive(:mark).with(any_args)
      expect(service).to receive(:mark).with('pusher.ignore')
      expect(pusher_client).to receive(:push).with(any_args)

      service.run(payload)
    end

    xit 'ignores a part if channel is not occupied' do
      expect(service).to receive(:channel_occupied?) { false }
      expect(service).to receive(:mark).with(any_args)
      expect(service).to receive(:mark).with('pusher.ignore')
      expect(pusher_client).to_not receive(:push)

      service.run(payload)
    end

    xit 'sends a part if channel is occupied' do
      expect(service).to receive(:channel_occupied?) { true }
      expect(service).to receive(:mark).with(any_args)
      expect(service).to receive(:mark).with('pusher.send')
      expect(pusher_client).to receive(:push).with(any_args)

      service.run(payload)
    end
  end

  context 'when pusher.secure is true' do
    before(:each) do
      Travis.config.pusher.secure = true
    end

    xit 'notifies pusher on a private channel' do
      expect(pusher_client).to receive(:push)
        .with(
          'id' => 2, 'chars' => 'hello, world', 'number' => 1, 'final' => false
        )
      service.run(payload)
    end
  end

  context 'when pusher.secure is false' do
    before(:each) do
      Travis.config.pusher.secure = false
    end

    xit 'notifies pusher on a regular channel' do
      expect(pusher_client).to receive(:push)
        .with(
          'id' => 2, 'chars' => 'hello, world', 'number' => 1, 'final' => false
        )
      service.run(payload)
    end
  end
end
