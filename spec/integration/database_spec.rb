# frozen_string_literal: true

describe Travis::Logs::Database do
  let(:database) { described_class.new }
  let(:sequel) { described_class.create_sequel }
  let(:now) { Time.now.utc }

  before(:each) do
    sequel[:logs].delete
    sequel[:log_parts].delete
    sequel << "SET TIME ZONE 'UTC'"
    database.instance_variable_set(:@db, sequel)
    database.connect
  end

  describe '#log_for_id' do
    context 'when the log exists' do
      let(:log) { { content: 'hello, world', job_id: 2 } }

      before(:each) do
        @log_id = sequel[:logs].insert(log)
      end

      it 'returns the log' do
        expect(database.log_for_id(@log_id)).to include(log)
      end
    end

    context 'when the log does not exist' do
      it 'returns nil' do
        expect(database.log_for_id(1)).to be_nil
      end
    end
  end

  describe '#log_id_for_job_id' do
    context 'when the log exists' do
      let(:log) { { content: 'hello, world', job_id: 2 } }

      it 'returns the id of the log' do
        expect(database.log_id_for_job_id(2)).to eq(@log_id)
      end
    end

    context 'when the log does not exist' do
      it 'returns nil' do
        expect(database.log_id_for_job_id(1)).to be_nil
      end
    end
  end

  describe '#log_content_length_for_id' do
    context 'when the log exists' do
      let(:log) { { content: 'hello, world', job_id: 2 } }

      before(:each) do
        @log_id = sequel[:logs].insert(log)
      end

      it 'returns the content length of the log in a Hash' do
        expect(database.log_content_length_for_id(@log_id))
          .to eq(id: @log_id, job_id: 2, content_length: log[:content].length)
      end
    end

    context 'with a multi-byte string' do
      let(:log) { { content: "\u20AC123", job_id: 2 } }

      before do
        @log_id = sequel[:logs].insert(log)
      end

      it 'returns the number of bytes in the string' do
        expect(database.log_content_length_for_id(@log_id))
          .to eq(id: @log_id, job_id: 2, content_length: log[:content].bytesize)
      end
    end

    context 'when the log does not exist' do
      it 'returns nil' do
        expect(database.log_content_length_for_id(2)).to be_nil
      end
    end
  end

  describe '#update_archiving_status' do
    before(:each) do
      @log_id = sequel[:logs].insert(archiving: false)
    end

    it 'sets the archiving column' do
      database.update_archiving_status(@log_id, true)

      expect(sequel[:logs].where(id: @log_id).get(:archiving)).to be true
    end
  end

  describe '#mark_archive_verified' do
    before(:each) do
      @log_id = sequel[:logs].insert(archive_verified: false)
    end

    it 'sets archive_verified to be true' do
      database.mark_archive_verified(@log_id)

      verified = sequel[:logs].where(id: @log_id).get(:archive_verified)
      expect(verified).to be true
    end
  end

  describe '#create_log' do
    it 'creates the log with the given job ID' do
      database.create_log(2)

      expect(sequel[:logs].where(job_id: 2).count).to eq(1)
    end
  end

  describe '#create_log_part' do
    it 'creates a log part with the given parameters' do
      log_part = {
        log_id: 2,
        content: 'hello',
        number: 1,
        final: false
      }

      database.create_log_part(log_part)

      expect(sequel[:log_parts].first(log_id: 2)).to include(log_part)
    end
  end

  describe '#delete_log_parts' do
    it 'deletes all log parts with the given log ID' do
      sequel[:log_parts].multi_insert([
                                        { log_id: 2, content: 'hello', number: 1, final: false },
                                        { log_id: 2, content: 'world', number: 2, final: false },
                                        { log_id: 3, content: 'foobar', number: 1, final: false }
                                      ])

      database.delete_log_parts(2)

      expect(sequel[:log_parts].count).to eq(1)
    end
  end

  describe '#aggregatable_logs' do
    before(:each) do
      sequel[:log_parts].multi_insert([
                                        { log_id: 1, final: false, created_at: now - 60 * 60 * 24 },
                                        { log_id: 1, final: false, created_at: now - 60 * 60 * 24 },
                                        { log_id: 2, final: true, created_at: now - 60 * 60 }
                                      ])
    end

    it 'includes finished logs older than the regular interval' do
      log_ids = database.aggregatable_logs(60 * 30, 60 * 60 * 12, 500)

      expect(log_ids).to include(2)
    end

    it 'includes unfinished logs older than the forced interval' do
      log_ids = database.aggregatable_logs(60 * 30, 60 * 60 * 12, 500)

      expect(log_ids).to include(1)
    end

    it "doesn't include finished logs newer than the regular interval" do
      log_ids = database.aggregatable_logs(60 * 60 * 2, 60 * 60 * 12, 500)

      expect(log_ids).not_to include(2)
    end

    it "doesn't include unfinished logs newer than the forced interval" do
      log_ids = database.aggregatable_logs(60 * 30, 60 * 60 * 24 * 2, 500)

      expect(log_ids).not_to include(1)
    end

    it 'only includes each log_id once' do
      log_ids = database.aggregatable_logs(60 * 30, 60 * 60 * 12, 500)

      expect(log_ids).to eq(log_ids.uniq)
    end
  end

  describe '#aggregate' do
    before(:each) do
      @log_id = sequel[:logs].insert(aggregated_at: nil)
      sequel[:log_parts].multi_insert([
                                        { log_id: @log_id, content: 'world', number: 3 },
                                        { log_id: @log_id, content: 'hello ', number: 1 },
                                        { log_id: @log_id, content: '!', number: 4 }
                                      ])
    end

    it 'coalesces the log_parts ordered by number' do
      database.aggregate(@log_id)

      expect(sequel[:logs][id: @log_id][:content]).to eq('hello world!')
    end

    it 'sets the aggregated_at timestamp' do
      database.aggregate(@log_id)

      expect(sequel[:logs][id: @log_id][:aggregated_at]).not_to be_nil
    end
  end

  describe '#purge' do
    before(:each) do
      @log_id = sequel[:logs].insert(purged_at: nil, content: 'hello, world!')
    end

    it 'sets purged_at' do
      database.purge(@log_id)

      purged_at = sequel[:logs].where(id: @log_id).get(:purged_at)
      expect(purged_at).not_to be_nil
    end

    it 'clears the content' do
      database.purge(@log_id)

      content = sequel[:logs].where(id: @log_id).get(:content)
      expect(content).to be_nil
    end
  end

  describe '#mark_not_archived' do
    before do
      @log_id = sequel[:logs].insert(archived_at: Time.now.utc, archive_verified: true)
    end

    it 'nils out archived_at' do
      database.mark_not_archived(@log_id)

      archived_at = sequel[:logs].where(id: @log_id).get(:archived_at)
      expect(archived_at).to be_nil
    end

    it 'marks archive as not verified' do
      database.mark_not_archived(@log_id)

      verified = sequel[:logs].where(id: @log_id).get(:archive_verified)
      expect(verified).to be false
    end
  end

  describe '#set_log_content' do
    before do
      @log_id = sequel[:logs].insert(content: 'this is a test', aggregated_at: Time.now.utc)
    end

    it 'clears out the content' do
      database.set_log_content(@log_id, 'hello world')

      content = sequel[:logs].where(id: @log_id).get(:content)
      expect(content).to be == 'hello world'
    end

    it 'sets the aggregated_at time' do
      database.set_log_content(@log_id, 'hello world')

      aggregated_at = sequel[:logs].where(id: @log_id).get(:aggregated_at)
      expect(aggregated_at).to_not be_nil
    end
  end
end
