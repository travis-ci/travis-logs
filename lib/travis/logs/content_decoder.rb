# frozen_string_literal: true

require 'base64'

require 'coder'

module Travis
  module Logs
    class ContentDecoder
      class << self
        def decode_content(entry)
          if entry['encoding'] == 'base64'
            return Coder.clean!(
              Base64.decode64(
                entry['log']
              ).dup.force_encoding(Encoding::UTF_8)
            )
          end

          Coder.clean!(
            entry['log'].dup.force_encoding(Encoding::UTF_8)
          )
        end
      end
    end
  end
end
