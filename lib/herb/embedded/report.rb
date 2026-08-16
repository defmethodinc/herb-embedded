# frozen_string_literal: true

module Herb
  module Embedded
    # Aggregates LintResults across a run.
    class Report
      SEVERITY_RANK = { error: 3, warning: 2, info: 1, hint: 0 }.freeze

      def initialize
        @lint_results = []
      end

      def add(lint_result)
        @lint_results << lint_result
      end

      def diagnostics
        @lint_results.flat_map(&:diagnostics)
      end

      def files_checked
        @lint_results.size
      end

      def files_with_offenses
        @lint_results.select { |result| result.diagnostics.any? }.map(&:file).uniq.size
      end

      def correctable_count
        diagnostics.count(&:correctable?)
      end

      def exit_code(fail_level:)
        threshold = SEVERITY_RANK.fetch(fail_level)
        reached = diagnostics.any? { |diagnostic| SEVERITY_RANK.fetch(diagnostic.severity) >= threshold }
        reached ? 1 : 0
      end
    end
  end
end
