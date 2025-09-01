# frozen_string_literal: true

describe 'fetch_log_parts' do
  let(:subject) { Travis::Logs::Services::FetchLogParts.new }
  let(:job_id) { 1 }
  let(:db) { Travis::Logs.database_connection.db }


  before do
    Travis::Logs.database_connection = Travis::Logs::Database.connect
    Travis.config.logs.intervals[:sweeper] = 0
    db.run('TRUNCATE log_parts; TRUNCATE logs')
    PopulateLogParts.new.run
  end

  it 'fetches log_parts' do
    expect(db[:log_parts].count).to be > 0
    log_id = db[:log_parts].first[:log_id]
    result = subject.run(log_id:, job_id:, part_numbers: [1,2])
    expect(result.count).to eq(2)
    expect(result.pluck(:number)).to eq([1,2])
  end

  it 'fetches log_parts with `after` set' do
    expect(db[:log_parts].count).to be > 0
    log_id = db[:log_parts].first[:log_id]
    result = subject.run(log_id:, job_id:, part_numbers: [10,12, 16, 19], after: 15)
    expect(result.count).to eq(2)
    expect(result.pluck(:number)).to eq([16,19])
    expect(result.pluck(:content).any?(&:nil?)).to be false
  end

  it 'returns error log if part number does not exist and require_all is set' do
    expect(db[:log_parts].count).to be > 0
    log_id = db[:log_parts].first[:log_id]
    result = subject.run(log_id:, job_id:, part_numbers: [10,12, 13, 119], require_all: true)
    expect(result.count).to eq(1)
    expect(result.pluck(:number)).to eq([0])
    expect(result[0][:content]).to match('temporarily')
  end

  it 'returns log without content if content=false param is present' do
    expect(db[:log_parts].count).to be > 0
    log_id = db[:log_parts].first[:log_id]
    result = subject.run(log_id:, job_id:, part_numbers: [10,12, 13, 119], content:false)
    expect(result.count).to eq(3)
    expect(result.pluck(:content).all?(&:nil?)).to be true
  end
end
