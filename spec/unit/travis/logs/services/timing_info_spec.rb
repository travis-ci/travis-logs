# frozen_string_literal: true

require 'libhoney/test_client'

describe Travis::Logs::Services::TimingInfo do
  let(:content) { File.new('spec/fixtures/files/timing_info.log').read }

  let(:log) { { id: 1, job_id: 2, content: content } }
  let(:database) { double('database', update_archiving_status: nil, mark_archive_verified: nil, log_for_id: log, job_id_for_log_id: 2) }
  let(:service) { described_class.new(log[:job_id], database: database) }
  let(:honey) { Libhoney::TestClient.new }

  before do
    allow(database).to receive(:log_id_for_job_id).with(log[:job_id]).and_return(log[:id])
    expect(Travis::Honeycomb).to receive(:honey).and_return(honey)
    expect(honey).to receive(:builder).and_return(honey)
  end

  it 'builds honeycomb events' do
    service.run

    expect(honey.events).not_to be_empty
  end
end
