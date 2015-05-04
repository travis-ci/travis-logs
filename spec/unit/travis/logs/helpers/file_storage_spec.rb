require "travis/logs"
require 'travis/logs/helpers/file_storage'

module Travis::Logs::Helpers
  describe FileStorage do
    let(:file_storage) { described_class.new }
    before do
      Travis::Logs.config.file_storage["root_path"] = '/tmp'
    end

    it 'opens the correct file' do
      fs_temp = {}
      File.stub(:open) do |fname, mode|
        fs_temp[:opened] = fname
      end
      file_storage.store("foo_foo_foo_fll_fll_fll", 1);
      expect(fs_temp[:opened]).to eq(File.join("/tmp", "results_1.txt"))
    end

    it 'writes the correct content into file' do
      fs_temp = {}
      allow_any_instance_of(File).to receive(:write) do |buffer|
        fs_temp[:content] = buffer;
      end
      content = "Foo_foo_foo_fll_fll_fll";
      file_storage.store(content, 1)
      expect(fs_temp[:content]).to eq(content);
    end
  end
end
