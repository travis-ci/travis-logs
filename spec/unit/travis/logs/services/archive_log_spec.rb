require "travis/logs"
require "travis/support"
require "travis/logs/services/archive_log"
require "travis/logs/helpers/database"
require "travis/logs/helpers/reporting"
require "faraday"

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

module Travis::Logs::Services
  describe ArchiveLog do
    let(:log) { { id: 1, job_id: 2, content: "Hello, world!" } }
    let(:database) { double("database", mark_as_archiving: nil, mark_archive_verified: nil, log_for_id: log) }
    let(:storage_service) { FakeStorageService.new }
    let(:service) { described_class.new(log[:id], storage_service, database) }

    it "pushes the log to S3" do
      service.run

      expect(storage_service.objects["http://archive.travis-ci.org/jobs/#{log[:job_id]}/log.txt"]).to eq(log[:content])
    end

    it "marks the log as archiving, then unmarks" do
      expect(database).to receive(:mark_as_archiving).with(log[:id], true).ordered
      expect(database).to receive(:mark_as_archiving).with(log[:id], false).ordered

      service.run
    end

    it "marks the archive as verified" do
      service.run

      expect(database).to have_received(:mark_archive_verified).with(log[:id])
    end

    context "when the stored content length is different" do
      it "raises an error" do
        storage_service.return_incorrect_content_length!

        expect { service.run }.to raise_error
      end
    end
  end
end
