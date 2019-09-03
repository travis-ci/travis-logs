# frozen_string_literal: true

class FakeStorageService
  attr_reader :objects

  def initialize
    @objects = {}
    @content_length_offset = 0
  end

  def return_incorrect_content_length!
    @content_length_offset = -1
  end

  def store(content, url)
    @objects[url] = content
  end

  def content_length(url)
    @objects[url].length + @content_length_offset
  end
end

class FakeWarningLogger
  attr_reader :warnings

  def initialize
    @warnings = []
  end

  def warn(msg, args)
    @warnings << [msg, args]
  end

  def debug(*); end
end

describe Travis::Logs::Services::ArchiveLog do
  let(:content) { 'Hello, world!' }
  let(:log) { { id: 1, job_id: 2, content: content } }
  let(:database) { double('database', update_archiving_status: nil, mark_archive_verified: nil, log_for_id: log, job_id_for_log_id: 2) }
  let(:storage_service) { FakeStorageService.new }
  let(:service) { described_class.new(log[:id], storage_service: storage_service, database: database) }

  before do
    allow(service).to receive(:retry_times).and_return(0)
  end

  it 'pushes the log to S3' do
    service.run

    expect(storage_service.objects["http://archive-test.travis-ci.org/jobs/#{log[:job_id]}/log.txt"]).to eq(log[:content])
  end

  it 'marks the log as archiving, then unmarks' do
    expect(database).to receive(:update_archiving_status).with(log[:id], true).ordered
    expect(database).to receive(:update_archiving_status).with(log[:id], false).ordered

    service.run
  end

  it 'marks the archive as verified' do
    service.run

    expect(database).to have_received(:mark_archive_verified).with(log[:id])
  end

  context 'when the stored content length is different' do
    it 'raises an error' do
      storage_service.return_incorrect_content_length!

      expect { service.run }.to raise_error(Travis::Logs::Services::ArchiveLog::VerificationFailed)
    end
  end
end
