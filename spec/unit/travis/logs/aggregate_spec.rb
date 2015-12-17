require 'travis/logs/aggregate'

describe Travis::Logs::Aggregate do
  before do
    allow(Travis::Metrics).to receive(:setup)
    allow(Travis::Logs::Sidekiq).to receive(:setup)
    allow(Travis::Logs::Services::AggregateLogs).to receive(:prepare)
    allow(Travis::Logs::Services::AggregateLogs).to receive(:run)
    allow(subject).to receive(:run_periodically).and_yield
  end

  it 'sets up everything' do
    expect(subject.setup).to eql(:alldone)
  end

  it 'aggregates logs when running' do
    expect(subject).to receive(:aggregate_logs)
    expect(subject.run).to eql(:ran)
  end
end
