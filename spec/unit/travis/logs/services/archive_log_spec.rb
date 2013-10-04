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
    before(:each) do
      @db = Travis::Logs::Helpers::Database.connect
      @db[:logs].delete
      @db[:log_parts].delete
      Travis::Logs.database_connection = @db
    end

    it "pushes the log to S3" do
      log_id = @db[:logs].insert(job_id: 123, created_at: Time.now.utc, updated_at: Time.now.utc, content: "Hello, world!")
      storage_service = FakeStorageService.new

      Travis::Logs::Services::ArchiveLog.new(log_id, storage_service).run

      expect(storage_service.objects["http://archive.travis-ci.org/jobs/123/log.txt"]).to eq("Hello, world!")
    end

    context "when the stored content length is different" do
      it "raises an error" do
        log_id = @db[:logs].insert(job_id: 123, created_at: Time.now.utc, updated_at: Time.now.utc, content: "Hello, world!")
        storage_service = FakeStorageService.new
        storage_service.return_incorrect_content_length!

        expect { Travis::Logs::Services::ArchiveLog.new(log_id, storage_service).run }.to raise_error
      end
    end
  end
end
