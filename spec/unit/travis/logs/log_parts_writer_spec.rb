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

  alias cached_log_id_for_job_id log_id_for_job_id
end

describe Travis::Logs::LogPartsWriter do
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

  let(:database) { FakeDatabase.new }

  subject(:service) do
    described_class.new(database: database)
  end

  before(:each) do
    Travis.config.channels_existence_check = true
    Travis.config.channels_existence_metrics = true
    Travis::Logs.cache.clear
    allow(Metriks).to receive(:meter).and_return(double('meter', mark: nil))
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
      expect(meter).to receive(:mark).at_most(2).times
      service.run(payload)
    end
  end

  it 'creates a log part' do
    service.run(payload)

    log_part = database.log_parts.last
    expect(log_part[:content]).to include('hello, world')
    expect(log_part[:content]).to include('wowbytes')
    expect(log_part[:number]).to be > 0
    expect(log_part[:final]).to be false
  end
end
