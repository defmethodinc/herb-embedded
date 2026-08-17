# frozen_string_literal: true

module Herb
  module Embedded
    module Formatters
      # One "file:line:col severity message (rule)" line per offense, plus
      # a summary line.
      class Simple
        def render(report)
          lines = report.diagnostics.map { |diagnostic| format_diagnostic(diagnostic) }
          lines << summary(report)
          lines.join("\n")
        end

        private

        def format_diagnostic(diagnostic)
          "#{diagnostic.file}:#{diagnostic.line}:#{diagnostic.column} " \
            "#{diagnostic.severity} #{diagnostic.message} (#{diagnostic.rule})"
        end

        def summary(report)
          "#{report.files_checked} files checked, #{report.diagnostics.size} offenses"
        end
      end
    end
  end
end
