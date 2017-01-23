require 'travis/logs'
require 'travis/support'
require 'travis/logs/services/archive_log'
require 'travis/logs/helpers/database'
require 'faraday'

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

  def warn(msg)
    @warnings << msg
  end

  def debug(*); end
end

describe Travis::Logs::Services::ArchiveLog do
  let(:content) { 'Hello, world!' }
  let(:log) { { id: 1, job_id: 2, content: content } }
  let(:database) { double('database', update_archiving_status: nil, mark_archive_verified: nil, log_for_id: log) }
  let(:storage_service) { FakeStorageService.new }
  let(:service) { described_class.new(log[:id], storage_service, database) }

  it 'pushes the log to S3' do
    service.run

    expect(storage_service.objects["http://archive.travis-ci.org/jobs/#{log[:job_id]}/log.txt"]).to eq(log[:content])
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

  context 'without investigation enabled' do
    before do
      Travis.config.investigation[:enabled] = false
    end

    after do
      Travis.config.investigation = Hashr.new({
        enabled: false,
        investigators: {},
      })
    end

    it 'does not investigate the log content' do
      expect(service).to_not receive(:investigate)
      service.run
    end
  end

  context 'with investigation enabled' do
    let(:content) { "oh hai.\nHello, world!\namaze * 9000\n" }

    let :investigators do
      {
        amazement: {
          matcher: 'amaze.+\\b(?<level>\\d+)',
          marking_tmpl: 'amazement.%{level}',
          label_tmpl: 'amazement'
        },
        greetings: {
          matcher: 'oh hai',
          marking_tmpl: '',
          label_tmpl: 'ohhai'
        },
        kaboom: {
          matcher: "ERROR \\b(?<code>\d+)",
          marking_tmpl: 'kaboom.%{code}',
          label_tmpl: 'kaboom-code-%{code}'
        }
      }
    end

    let(:logger) { FakeWarningLogger.new }

    before do
      Travis.config.investigation[:enabled] = true
      Travis.config.investigation[:investigators] = investigators

      allow(Travis).to receive(:logger).and_return(logger)
    end

    after do
      Travis.config.investigation = Hashr.new({
        enabled: false,
        investigators: {},
      })
    end

    it 'investigates the log content' do
      expect(service).to receive(:investigate)
      service.run
    end

    it 'reports matching amazement' do
      expect(service).to receive(:mark).with('amazement.9000')
      service.run
      expect(Travis.logger.warnings.any? { |e| e =~ /\bresult=amazement\b/ }).to be true
    end

    it 'reports matching greeting' do
      expect(service).to_not receive(:mark).with(/greeting/)
      service.run
      expect(Travis.logger.warnings.any? { |e| e =~ /\bresult=ohhai\b/ }).to be true
    end

    it 'does not report matching kaboom' do
      expect(service).to_not receive(:mark).with(/kaboom/)
      service.run
      expect(Travis.logger.warnings.any? { |e| e =~ /\bresult=kaboom-code/ }).to_not be true
    end
  end
end
