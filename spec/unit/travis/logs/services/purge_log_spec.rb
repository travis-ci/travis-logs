require "travis/logs"
require "travis/support"
require "travis/logs/services/purge_log"

module Travis::Logs::Services
  describe PurgeLog do
    context "content is null" do
      context "log is on S3" do
        before(:each) do
          @database = double("database", mark_archive_verified: nil, purge: nil)
          @storage_service = double("storage", content_length: 1)
          @log = { content_length: nil }
          allow(@database).to receive(:log_content_length_for_id).with(1).and_return(@log)
          allow(@database).to receive(:transaction).and_yield
        end

        it "marks log as archived" do
          PurgeLog.new(@log[:id], @storage_service, @database).run
          expect(@database).to have_received(:mark_archive_verified).with(@log[:id])
        end

        it "purges the log" do
          PurgeLog.new(@log[:id], @storage_service, @database).run
          expect(@database).to have_received(:purge).with(@log[:id])
        end
      end

      context "log is not on S3" do
        before(:each) do
          @database = double("database")
          @storage_service = double("storage", content_length: nil)
          @log = { content_length: nil }
          allow(@database).to receive(:log_content_length_for_id).with(1).and_return(@log)
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
          @database = double("database", mark_archive_verified: nil, purge: nil, clear_log_content: nil)
          @storage_service = double("storage", content_length: 13)
          @log = { content_length: 13 }
          allow(@database).to receive(:log_content_length_for_id).with(1).and_return(@log)
        end

        it "purges the log" do
          PurgeLog.new(@log[:id], @storage_service, @database).run
          expect(@database).to have_received(:purge).with(@log[:id])
        end
      end

      context "content length does not match" do
        before do
          @database = double("database", mark_not_archived: nil)
          @storage_service = double("storage", content_length: 1)
          @log = { content_length: 13 }
          allow(@database).to receive(:log_content_length_for_id).with(1).and_return(@log)
        end

        it "marks the log as not archived" do
          PurgeLog.new(@log[:id], @storage_service, @database, ->(log_id) {}).run
          expect(@database).to have_received(:mark_not_archived).with(@log[:id])
        end

        it "queues the log for archiving" do
          archiver = double("archiver", call: nil)
          PurgeLog.new(@log[:id], @storage_service, @database, archiver).run
          expect(archiver).to have_received(:call).with(@log[:id])
        end
      end
    end
  end
end
