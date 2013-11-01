require "travis/support"
require "travis/logs"
require "travis/logs/services/purge_log"

module Travis::Logs::Services
  describe PurgeLog do
    context "content is null" do
      context "log is on S3" do
        before(:each) do
          @database = double("database", mark_archive_verified: nil, mark_purged: nil)
          @storage_service = double("storage", content_length: 1)
          @log = { id: 1, job_id: 2, content: nil }
          allow(@database).to receive(:log_for_id).with(1).and_return(@log)
        end

        it "marks log as archived" do
          PurgeLog.new(@log[:id], @storage_service, @database).run
          expect(@database).to have_received(:mark_archive_verified).with(@log[:id])
        end

        it "marks log as purged" do
          PurgeLog.new(@log[:id], @storage_service, @database).run
          expect(@database).to have_received(:mark_purged).with(@log[:id])
        end
      end

      context "log is not on S3" do
        before(:each) do
          @database = double("database")
          @storage_service = double("storage", content_length: nil)
          @log = { id: 1, job_id: 2, content: nil }
          allow(@database).to receive(:log_for_id).with(1).and_return(@log)
        end

        it "prints a warning" do
          expect(Travis.logger).to receive(:warn).with(/id:1.+missing/i)
          PurgeLog.new(@log[:id], @storage_service, @database).run
        end
      end
    end

    context "content is not null" do
      context "content length matches S3" do
        before(:each) do
          @database = double("database", mark_archive_verified: nil, mark_purged: nil, clear_log_content: nil)
          @storage_service = double("storage", content_length: 13)
          @log = { id: 1, job_id: 2, content: "hello, world!" }
          allow(@database).to receive(:log_for_id).with(1).and_return(@log)
        end

        it "marks log as purged" do
          PurgeLog.new(@log[:id], @storage_service, @database).run
          expect(@database).to have_received(:mark_purged).with(@log[:id])
        end

        it "clears the log content" do
          PurgeLog.new(@log[:id], @storage_service, @database).run
          expect(@database).to have_received(:clear_log_content).with(@log[:id])
        end
      end
    end
  end
end
