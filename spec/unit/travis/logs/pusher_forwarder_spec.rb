# frozen_string_literal: true

describe Travis::Logs::PusherForwarder do
  let(:payload) do
    [
      {
        'id' => 2,
        'log' => Base64.strict_encode64(
          "hello, world \xfa\xca\xde\x86wowbytes"
        ),
        'encoding' => 'base64',
        'number' => 2
      },
      {
        'id' => 2,
        'log' => "hello, world \xfa\xca\xde\x86wowbytes",
        'number' => 1
      }
    ]
  end

  let(:pusher_client) { double('pusher client') }
  let(:database) { double('database') }
  let(:existence) { double('existence') }
  let(:log_parts_normalizer) { double('log parts normalizer') }

  subject(:service) do
    described_class.new(
      database: database,
      existence: existence,
      log_parts_normalizer: log_parts_normalizer,
      pusher_client: pusher_client
    )
  end

  before(:each) do
    Travis.config.channels_existence_check = true
    Travis.config.channels_existence_metrics = true
    Travis::Logs.cache.clear
    allow(Metriks).to receive(:meter).and_return(double('meter', mark: nil))
    allow(service).to receive(:channel_occupied?) { true }
    allow(service).to receive(:channel_name) { 'channel' }
    allow(log_parts_normalizer).to receive(:run) do |payload|
      payload.map { |entry| [entry['id'], entry] }
    end
  end

  describe 'existence check' do
    it 'sends a part if channel is not occupied but the existence check is disabled' do
      allow(service).to receive(:existence_check?).and_return(false)
      allow(service).to receive(:channel_occupied?).and_return(false)
      expect(service).to receive(:mark).with('pusher.ignore').exactly(2).times
      expect(pusher_client).to receive(:push).with(any_args).exactly(2).times

      service.run(payload)
    end

    it 'ignores a part if channel is not occupied' do
      allow(service).to receive(:existence_check?).and_return(true)
      allow(service).to receive(:channel_occupied?).and_return(false)
      expect(service).to receive(:mark).with('pusher.ignore').exactly(2).times
      expect(pusher_client).to_not receive(:push)

      service.run(payload)
    end

    it 'sends a part if channel is occupied' do
      allow(service).to receive(:channel_occupied?).and_return(true)
      expect(service).to receive(:mark).with('pusher.send').exactly(2).times
      expect(pusher_client).to receive(:push).with(any_args).exactly(2).times

      service.run(payload)
    end
  end

  context 'when pusher.secure is true' do
    before(:each) do
      Travis.config.pusher.secure = true
    end

    it 'notifies pusher on a private channel' do
      expect(pusher_client).to receive(:push)
        .with(
          'id' => 2,
          'chars' => "hello, world \xde\x86wowbytes",
          'number' => anything,
          'final' => false
        ).exactly(2).times
      service.run(payload)
    end
  end

  context 'when pusher.secure is false' do
    before(:each) do
      Travis.config.pusher.secure = false
    end

    it 'notifies pusher on a regular channel' do
      expect(pusher_client).to receive(:push)
        .with(
          'id' => 2,
          'chars' => "hello, world \xde\x86wowbytes",
          'number' => anything,
          'final' => false
        ).exactly(2).times
      service.run(payload)
    end
  end
end
