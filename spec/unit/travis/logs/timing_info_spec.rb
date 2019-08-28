describe Travis::Logs::Services::TimingInfo do
  let(:database) { double(Travis::Logs::Database) }
  let(:archiver) { Travis::Logs::Sidekiq::Archive }
  let(:log_id) { rand(10_000..19_999) }

  subject(:service) { described_class.new(database) }

  before(:each) do
    allow(archiver).to receive(:perform_async)
    allow(database)
      .to receive_message_chain(:db, :transaction) { |&block| block.call }
    allow(database).to receive(:aggregatable_logs).and_return([1, 2])
    allow(database).to receive(:log_for_id) { |id| { id: id, content: 'foo' } }
    allow(database).to receive(:aggregate)
    allow(database).to receive(:delete_log_parts)
    allow(service).to receive(:skip_empty?) { true }
  end

  it 'exposes .run' do
    expect(described_class).to respond_to(:run)
  end
end
