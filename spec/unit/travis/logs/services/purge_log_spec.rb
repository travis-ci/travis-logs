# frozen_string_literal: true

describe Travis::Logs::Services::PurgeLog do
  context 'content is null' do
    before do
      @database = double('database', mark_archive_verified: nil, purge: nil)
      @log_id = 1
      allow(@database).to receive(:log_content_length_for_id).with(@log_id).and_return(content_length: nil)
      allow(@database).to receive_message_chain(:db, :transaction).and_yield
    end

    context 'log is on S3' do
      before do
        @storage_service = double('storage', content_length: 1)
      end

      it 'marks log as archived' do
        described_class.new(@log_id, @storage_service, @database).run
        expect(@database).to have_received(:mark_archive_verified).with(@log_id)
      end

      it 'purges the log' do
        described_class.new(@log_id, @storage_service, @database).run
        expect(@database).to have_received(:purge).with(@log_id)
      end
    end

    context 'log is not on S3' do
      before(:each) do
        @storage_service = double('storage', content_length: nil)
      end

      it 'prints a warning' do
        expect(Travis.logger).to receive(:warn)
          .with(anything, hash_including(id: 1, result: 'content_missing'))
        described_class.new(@log_id, @storage_service, @database).run
      end
    end
  end

  context 'content is not null' do
    before do
      @database = double('database', mark_archive_verified: nil, purge: nil, clear_log_content: nil, mark_not_archived: nil)
      @log_id = 1
      allow(@database).to receive(:log_content_length_for_id).with(@log_id).and_return(content_length: 13)
    end

    context 'content length matches S3' do
      before do
        @storage_service = double('storage', content_length: 13)
      end

      it 'purges the log' do
        described_class.new(@log_id, @storage_service, @database).run
        expect(@database).to have_received(:purge).with(@log_id)
      end
    end

    context 'content length does not match' do
      before do
        @storage_service = double('storage', content_length: 1)
      end

      it 'marks the log as not archived' do
        described_class.new(@log_id, @storage_service, @database, ->(log_id) {}).run
        expect(@database).to have_received(:mark_not_archived).with(@log_id)
      end

      it 'queues the log for archiving' do
        archiver = double('archiver', call: nil)
        described_class.new(@log_id, @storage_service, @database, archiver).run
        expect(archiver).to have_received(:call).with(@log_id)
      end
    end
  end
end
