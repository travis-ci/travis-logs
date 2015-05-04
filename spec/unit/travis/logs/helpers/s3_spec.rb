require 'travis/config'
require 'travis/logs/helpers/log_storage_provider'
module Travis::Logs::Helpers
  describe S3 do
    let(:s3) do
      Travis::Logs.config.log_storage_provider = "s3"
      Travis::Logs.config.s3.hostname = "Fooserver_ip"
      return described_class.new
    end

    it 'uses file_storage when specified' do
      expect(s3.instance_eval { target_uri(1) }).to include("http://Fooserver_ip")
    end
  end
end
