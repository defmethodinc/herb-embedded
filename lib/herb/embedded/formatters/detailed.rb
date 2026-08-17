# frozen_string_literal: true

module Herb
  module Embedded
    module Formatters
      # Offenses grouped by file, with correctable offenses flagged.
      class Detailed
        def render(report)
          report.diagnostics
                .group_by(&:file)
                .flat_map { |file, diagnostics| render_file(file, diagnostics) }
                .join("\n")
        end

        private

        def render_file(file, diagnostics)
          ["#{file}:"] + diagnostics.map { |diagnostic| render_diagnostic(diagnostic) }
        end

        def render_diagnostic(diagnostic)
          flag = diagnostic.correctable? ? " [correctable]" : ""
          "  #{diagnostic.line}:#{diagnostic.column} #{diagnostic.severity} " \
            "#{diagnostic.message} (#{diagnostic.rule})#{flag}"
        end
      end
    end
  end
end
