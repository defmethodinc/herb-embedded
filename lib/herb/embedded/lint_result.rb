# frozen_string_literal: true

module Herb
  module Embedded
    # The diagnostics produced for a single file.
    class LintResult
      attr_reader :file, :diagnostics

      def initialize(file:, diagnostics: [])
        @file = file
        @diagnostics = diagnostics
      end
    end
  end
end
