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
  let(:storage_service) { FakeStorageService.new }

  let(:config) do
    {
      s3: {
        hostname: 'archive-test.travis-ci.org'
      },
      logs: {
        purge: true,
        intervals: {
          purge: 1
        }
      }
    }
  end

  let(:database) do
    double(
      'database',
      update_archiving_status: nil,
      mark_archive_verified: nil,
      log_for_id: log
    )
  end

  subject(:service) do
    described_class.new(
      log[:id], storage_service: storage_service, database: database
    )
  end

  before do
    allow(Travis::Logs).to receive(:config).and_return(config)
    allow(Travis::Logs::Sidekiq::Purge).to receive(:perform_at)
  end

  it 'pushes the log to S3' do
    subject.run

    key = "http://archive-test.travis-ci.org/jobs/#{log[:job_id]}/log.txt"
    expect(storage_service.objects[key]).to eql(log[:content])
  end

  it 'marks the log as archiving, then unmarks' do
    expect(database).to receive(:update_archiving_status)
      .with(log[:id], true).ordered
    expect(database).to receive(:update_archiving_status)
      .with(log[:id], false).ordered

    subject.run
  end

  it 'marks the archive as verified' do
    subject.run

    expect(database).to have_received(:mark_archive_verified).with(log[:id])
  end

  context 'when the stored content length is different' do
    it 'raises an error' do
      storage_service.return_incorrect_content_length!

      expect { subject.run }
        .to raise_error(Travis::Logs::Services::ArchiveLog::VerificationFailed)
    end
  end

  context 'when the log is not found' do
    let(:log) { nil }

    subject(:service) do
      described_class.new(
        8, storage_service: storage_service, database: database
      )
    end

    it 'exits early' do
      expect(database).to_not receive(:update_archiving_status)
        .with(8, true)
      subject.run
    end

    it 'marks log.not_found' do
      expect(subject).to receive(:mark).with('log.not_found')
      subject.run
    end
  end

  context 'when the log content is empty' do
    let(:log) { { id: 9, job_id: 4, content: '' } }

    subject(:service) do
      described_class.new(
        9, storage_service: storage_service, database: database
      )
    end

    it 'exits early' do
      expect(database).to_not receive(:update_archiving_status)
        .with(9, true)
      subject.run
    end

    it 'marks log.empty' do
      expect(subject).to receive(:mark).with('log.empty')
      subject.run
    end
  end
end
