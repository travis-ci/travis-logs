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
  let(:payload) { [{ 'id' => 2, 'log' => 'hello, world', 'number' => 1 }] }
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
    xit 'creates a log' do
      service.run(payload)

      expect(database.log_id_for_job_id(2)).not_to be_nil
    end

    xit 'marks the log.create metric' do
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

    xit 'does not create another log' do
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

    xit 'marks the log.id_invalid metric' do
      expect(meter).to receive(:mark)
      service.run(payload)
    end
  end

  xit 'creates a log part' do
    service.run(payload)

    expect(database.log_parts.last).to include(
      content: 'hello, world', number: 1, final: false
    )
  end
end
