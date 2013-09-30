require "travis/logs"
require "travis/support"
require "travis/logs/services/process_log_part"
require "travis/logs/helpers/database"
require "travis/logs/helpers/reporting"

module Travis::Logs::Services
  describe ProcessLogPart do
    before(:each) do
      @db = Travis::Logs::Helpers::Database.connect
      @db[:logs].delete
      @db[:log_parts].delete
      Travis::Logs.database_connection = @db
      Travis::Logs::Services::ProcessLogPart.prepare(@db)
    end

    context "without an existing log" do
      it "creates a log" do
        Travis::Logs::Services::ProcessLogPart.new({ "id" => 123, "log" => "hello, world", "number" => 1}).run

        expect(@db[:logs].where(job_id: 123).count).to eq(1)
      end
    end

    context "with an existing log" do
      before(:each) do
        @db[:logs].insert(job_id: 123, created_at: Time.now.utc, updated_at: Time.now.utc)
      end

      it "does not create another log" do
        Travis::Logs::Services::ProcessLogPart.new({ "id" => 123, "log" => "hello, world", "number" => 1}).run

        expect(@db[:logs].where(job_id: 123).count).to eq(1)
      end
    end

    it "creates a log part" do
      Travis::Logs::Services::ProcessLogPart.new({ "id" => 123, "log" => "hello, world", "number" => 1}).run

      expect(@db[:log_parts].where(content: "hello, world", number: 1, final: false).count).to eq(1)
    end

    it "notifies pusher" do
      pusher_channel = double("pusher_channel", trigger: nil)
      pusher_client = double("pusher_client", :[] => pusher_channel)
      allow(Travis::Logs.config).to receive(:pusher_client) { pusher_client }

      Travis::Logs::Services::ProcessLogPart.new({ "id" => 123, "log" => "hello, world", "number" => 1}).run

      pusher_client.should have_received(:[]).with("job-123")
      pusher_channel.should have_received(:trigger).with("job:log", { "id" => 123, "_log" => "hello, world", "number" => 1, "final" => false })
    end
  end
end
