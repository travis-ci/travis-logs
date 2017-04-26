# frozen_string_literal: true

class FakeDatabase
  attr_reader :logs, :log_parts

  def initialize
    @logs = []
    @log_parts = []
  end

  def create_log(job_id, log_id = @logs.length + 1)
    @logs << { id: log_id, job_id: job_id, content: '' }
    log_id
  end

  def create_log_parts(entries)
    log_part_id = @log_parts.length + entries.length
    @log_parts += entries
    log_part_id
  end

  def log_id_for_job_id(job_id)
    @logs.select { |log| log[:job_id] == job_id }.map { |log| log[:id] }.first
  end
end

describe Travis::Logs::Services::ProcessLogPart do
  let(:payload) { [{ 'id' => 2, 'log' => 'hello, world', 'number' => 1 }] }
  let(:database) { FakeDatabase.new }
  let(:pusher_client) { double('pusher-client', push: nil) }

  subject(:service) do
    described_class.new(
      database: database,
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
  end

  context 'without an existing log' do
    it 'creates a log' do
      service.run(payload)

      expect(database.log_id_for_job_id(2)).not_to be_nil
    end

    it 'marks the log.create metric' do
      meter = double('log.create meter')
      expect(Metriks).to receive(:meter).with('logs.process_log_part.log.create').and_return(meter)
      expect(meter).to receive(:mark)

      service.run(payload)
    end
  end

  context 'with an existing log' do
    before(:each) do
      database.create_log(2)
    end

    it 'does not create another log' do
      service.run(payload)

      expect(database.logs.count { |log| log[:job_id] == 2 }).to eq(1)
    end
  end

  context 'with an invalid log ID' do
    let(:meter) { double('log.id_invalid meter') }

    before(:each) do
      database.create_log(2, 0)
      allow(Metriks).to receive(:meter)
        .with('logs.process_log_part.log.id_invalid').and_return(meter)
    end

    it 'marks the log.id_invalid metric' do
      expect(meter).to receive(:mark)
      service.run(payload)
    end
  end

  it 'creates a log part' do
    service.run(payload)

    expect(database.log_parts.last).to include(
      content: 'hello, world', number: 1, final: false
    )
  end

  describe 'existence check' do
    it 'sends a part if channel is not occupied but the existence check is disabled' do
      expect(service).to receive(:existence_check?) { false }
      expect(service).to receive(:channel_occupied?) { false }
      expect(service).to receive(:mark).with(any_args)
      expect(service).to receive(:mark).with('pusher.ignore')
      expect(pusher_client).to receive(:push).with(any_args)

      service.run(payload)
    end

    it 'ignores a part if channel is not occupied' do
      expect(service).to receive(:channel_occupied?) { false }
      expect(service).to receive(:mark).with(any_args)
      expect(service).to receive(:mark).with('pusher.ignore')
      expect(pusher_client).to_not receive(:push)

      service.run(payload)
    end

    it 'sends a part if channel is occupied' do
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

    it 'notifies pusher on a private channel' do
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

    it 'notifies pusher on a regular channel' do
      expect(pusher_client).to receive(:push)
        .with(
          'id' => 2, 'chars' => 'hello, world', 'number' => 1, 'final' => false
        )
      service.run(payload)
    end
  end
end
