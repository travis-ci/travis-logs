# frozen_string_literal: true
module Travis
  module Logs
    Investigator = Struct.new(:name, :matcher, :marking_tmpl, :label_tmpl) do
      Result = Struct.new(:marking, :label)

      def investigate(content)
        match = matcher.match(content)
        return nil unless match

        match_hash = Hash[match.names.map(&:to_sym).zip(match.captures)]

        Result.new(
          format(marking_tmpl, match_hash),
          format(label_tmpl, match_hash)
        )
      end
    end
  end
end
