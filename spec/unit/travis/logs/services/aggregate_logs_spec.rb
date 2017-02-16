require 'travis/logs'
require 'travis/support'
require 'travis/logs/sidekiq'
require 'travis/logs/services/aggregate_logs'
require 'travis/logs/helpers/database'

describe Travis::Logs::Services::AggregateLogs do
  let(:database) { double('database') }
  let(:archiver) { Travis::Logs::Sidekiq::Archive }
  let(:log_id) { rand(10_000..19_999) }

  subject(:service) { described_class.new(database) }

  before(:each) do
    allow(archiver).to receive(:perform_async)
    allow(database).to receive(:transaction) { |&block| block.call }
    allow(database).to receive(:aggregatable_log_parts).and_return([1, 2])
    allow(database).to receive(:log_for_id) { |id| { id: id, content: 'foo' } }
    allow(database).to receive(:aggregate)
    allow(database).to receive(:delete_log_parts)
  end

  it 'exposes .run' do
    expect(described_class).to respond_to(:run)
  end

  it 'runs #run via .run' do
    expect(described_class).to receive(:new).and_return(service)
    expect(service).to receive(:run)
    described_class.run
  end

  it 'exposes .aggregate_log' do
    expect(described_class).to respond_to(:aggregate_log)
  end

  it 'runs #aggregate_log via .aggregate_log' do
    expect(described_class).to receive(:new).and_return(service)
    expect(service).to receive(:aggregate_log).with(log_id)
    described_class.aggregate_log(log_id)
  end

  it 'aggregates every aggregatable log' do
    service.run

    expect(database).to have_received(:aggregate).with(1)
    expect(database).to have_received(:aggregate).with(2)
  end

  it 'vacuums every aggregatable log' do
    service.run

    expect(database).to have_received(:delete_log_parts).with(1)
    expect(database).to have_received(:delete_log_parts).with(2)
  end

  context 'when a the log exists' do
    it 'queues the log for archiving' do
      service.run

      expect(archiver).to have_received(:perform_async).with(1)
      expect(archiver).to have_received(:perform_async).with(2)
    end
  end

  context "when log content is ''" do
    before do
      allow(database).to receive(:log_for_id) { |id| { id: id, content: '' } }
    end

    it 'does not vacuum log parts' do
      begin
        service.run
      rescue
      end

      expect(database).not_to have_received(:delete_log_parts).with(1)
      expect(database).not_to have_received(:delete_log_parts).with(2)
    end
  end

  context 'when log content is nil' do
    before do
      allow(database).to receive(:log_for_id) { |id| { id: id, content: nil } }
    end

    it 'does not vacuum log parts' do
      begin
        service.run
      rescue
      end

      expect(database).not_to have_received(:delete_log_parts).with(1)
      expect(database).not_to have_received(:delete_log_parts).with(2)
    end
  end
end
