require "travis/logs"
require "travis/support"
require "travis/logs/services/archive_log"
require "travis/logs/helpers/database"
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

  def store(content, log_id)
    @objects[log_id] = content
  end

  def content_length(log_id)
    @objects[log_id].length + @content_length_offset
  end

  def target_uri(log_id)
    "protocol://#{log_id}"
  end
end

module Travis::Logs::Services
  describe ArchiveLog do
    let(:log) { { id: 1, job_id: 2, content: "Hello, world!" } }
    let(:database) { double("database", update_archiving_status: nil, mark_archive_verified: nil, log_for_id: log) }
    let(:storage_service) { FakeStorageService.new }
    let(:service) { described_class.new(log[:id], storage_service, database) }

    it "pushes the log to S3" do
      service.run

      expect(storage_service.objects[log[:job_id]]).to eq(log[:content])
    end

    it "marks the log as archiving, then unmarks" do
      expect(database).to receive(:update_archiving_status).with(log[:id], true).ordered
      expect(database).to receive(:update_archiving_status).with(log[:id], false).ordered

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
