require 'travis/logs'

module Travis
  module Logs
    module Helpers
      class FileStorage

        class << self
          def setup
          end
        end

        def store(data, log_id)
          File.open(log_filename(log_id), 'wb') do |f|
            f.write data
          end
        end

        def content_length(log_id)
          File.stat(log_filename(log_id)).size
        end

        def target_uri(log_id)
          "file://#{log_filename(log_id)}"
        end

      private

        def log_filename(log_id)
          File.join(Travis::Logs.config.file_storage.root_path, "results_#{log_id.to_s}.txt")
        end
      end
    end
  end
end
