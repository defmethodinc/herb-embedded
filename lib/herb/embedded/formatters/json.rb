# frozen_string_literal: true

require "json"

module Herb
  module Embedded
    module Formatters
      # { offenses: [...], summary: { files_checked, offenses, correctable } }
      class Json
        def render(report)
          {
            offenses: report.diagnostics.map { |diagnostic| offense_hash(diagnostic) },
            summary: {
              files_checked: report.files_checked,
              offenses: report.diagnostics.size,
              correctable: report.correctable_count,
            },
          }.to_json
        end

        private

        def offense_hash(diagnostic)
          diagnostic.to_h.merge(
            file: diagnostic.file,
            line: diagnostic.line,
            column: diagnostic.column,
            correctable: diagnostic.correctable?,
          )
        end
      end
    end
  end
end
