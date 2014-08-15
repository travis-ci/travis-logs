require "travis/logs"
require "travis/support"
require "travis/logs/services/process_log_part"
require "travis/logs/helpers/database"
require "travis/logs/helpers/reporting"

class FakeDatabase
  attr_reader :logs, :log_parts

  def initialize
    @logs = []
    @log_parts = []
  end

  def create_log(job_id, log_id = @logs.length + 1)
    @logs << { id: log_id, job_id: job_id, content: "" }
    log_id
  end

  def create_log_part(params)
    log_part_id = @log_parts.length + 1
    @log_parts << params
    log_part_id
  end

  def log_for_job_id(job_id)
    @logs.find { |log| log[:job_id] == job_id }
  end
end

module Travis::Logs::Services
  describe ProcessLogPart do
    let(:payload) { { "id" => 2, "log" => "hello, world", "number" => 1 } }
    let(:database) { FakeDatabase.new }
    let(:pusher_client) { double("pusher-client", push: nil, pusher_channel_name: 'channel') }

    let(:service) { described_class.new(payload, database, pusher_client) }

    before(:each) do
      allow(Metriks).to receive(:meter).and_return(double("meter", mark: nil))
    end

    context "without an existing log" do
      it "creates a log" do
        service.run

        expect(database.log_for_job_id(2)).not_to be_nil
      end

      it "marks the log.create metric" do
        meter = double("log.create meter")
        expect(Metriks).to receive(:meter).with("logs.process_log_part.log.create").and_return(meter)
        expect(meter).to receive(:mark)

        service.run
      end
    end

    context "with an existing log" do
      before(:each) do
        database.create_log(2)
      end

      it "does not create another log" do
        service.run

        expect(database.logs.count { |log| log[:job_id] == 2 }).to eq(1)
      end
    end

    context "with an invalid log ID" do
      before(:each) do
        database.create_log(2, 0)
      end

      it "marks the log.id_invalid metric" do
        meter = double("log.id_invalid meter")
        expect(Metriks).to receive(:meter).with("logs.process_log_part.log.id_invalid").and_return(meter)
        expect(meter).to receive(:mark)

        service.run
      end
    end

    it "creates a log part" do
      service.run

      expect(database.log_parts.last).to include(content: "hello, world", number: 1, final: false)
    end

    context "when pusher.secure is true" do
      before(:each) do
        Travis::Logs.config.pusher.secure = true
      end

      it "notifies pusher on a private channel" do
        service.run

        pusher_client.should have_received(:push).with({
          "id" => 2,
          "chars" => "hello, world",
          "number" => 1,
          "final" => false
        })
      end
    end

    context "when pusher.secure is false" do
      before(:each) do
        Travis::Logs.config.pusher.secure = false
      end

      it "notifies pusher on a regular channel" do
        service.run

        pusher_client.should have_received(:push).with({
          "id" => 2,
          "chars" => "hello, world",
          "number" => 1,
          "final" => false
        })
      end
    end
  end
end
