# frozen_string_literal: true

module Herb
  module Embedded
    module Formatters
      # One GitHub Actions annotation line per offense:
      # ::error file=...,line=...,col=...::message
      class Github
        def render(report)
          report.diagnostics.map { |diagnostic| annotation(diagnostic) }.join("\n")
        end

        private

        def annotation(diagnostic)
          "::error file=#{diagnostic.file},line=#{diagnostic.line},col=#{diagnostic.column}::#{diagnostic.message}"
        end
      end
    end
  end
end
