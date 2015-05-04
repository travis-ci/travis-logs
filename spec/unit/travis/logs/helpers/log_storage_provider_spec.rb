require 'travis/config'
require 'travis/logs/helpers/log_storage_provider'


module Travis::Logs::Helpers
  describe LogStorageProvider do
    it 'uses file_storage when specified' do
      Travis::Logs.config.log_storage_provider = "file_storage"
      expect(described_class.provider).to eq(Travis::Logs::Helpers::FileStorage)
    end

    it 'uses s3 when specified' do
      Travis::Logs.config.log_storage_provider = "s3"
      expect(described_class.provider).to eq(Travis::Logs::Helpers::S3)
    end
  end
end
