# frozen_string_literal: true

module Herb
  module Embedded
    # A single lint offense. Shaped to match upstream Herb::Diagnostic /
    # Herb::LintOffense (marcoroth/herb#455, unmerged): #to_h's key set
    # mirrors that class's #to_h exactly, so this drops into its socket
    # without rewriting every consumer if/when that PR lands. #file,
    # #line, #column, and #correctable? are this gem's own convenience
    # accessors on top of that shape — upstream has no per-file scope
    # (a single Herb.lint call is per-source) and derives correctability
    # from a rule's static autocorrectable flag rather than a reader.
    class Diagnostic
      SEVERITIES = %i[error warning info hint].freeze
      DEFAULT_SEVERITY = :error

      attr_reader :file, :rule, :message, :severity, :location, :code, :source

      # rubocop:disable Metrics/ParameterLists -- value object, one flat field per keyword
      def initialize(file:, rule:, message:, severity:, location:, code: nil, source: nil, correctable: false)
        @file = file
        @rule = rule
        @message = message
        @severity = SEVERITIES.include?(severity) ? severity : DEFAULT_SEVERITY
        @location = location
        @code = code
        @source = source
        @correctable = correctable
      end
      # rubocop:enable Metrics/ParameterLists

      def self.from_js(hash, file:)
        new(
          file: file,
          rule: hash["rule"],
          message: hash["message"],
          severity: hash["severity"]&.to_sym,
          location: hash["location"],
          code: hash["code"],
          source: hash["source"],
          correctable: !hash["autofixContext"].nil?,
        )
      end

      def line
        location&.dig("start", "line")
      end

      def column
        location&.dig("start", "column")
      end

      def correctable?
        @correctable
      end

      def to_h
        {
          message: message,
          location: location,
          severity: severity,
          code: code,
          source: source,
          rule: rule,
        }
      end
    end
  end
end
