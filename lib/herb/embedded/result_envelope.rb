# frozen_string_literal: true

require "herb"
require "json"

module Herb
  module Embedded
    # Herb::ParseResult#to_json returns an inspect string, not the wire
    # format @herb-tools/core's ParseResult.from() expects. This builds
    # that envelope by hand from the pieces that do serialize correctly.
    module ResultEnvelope
      # Allowlist of Herb::ParserOptions keys safe to forward from
      # caller-supplied options. Deliberately excludes prism_nodes,
      # prism_nodes_deep, and prism_program: Prism data crosses the
      # engine boundary as binary (Uint8Array), and forwarding it here
      # raises JSON::GeneratorError on ASCII-8BIT content. Also excludes
      # timeout and max_errors (timing/error-cap options, not shape).
      FORWARDABLE_OPTIONS = %i[
        strict
        track_whitespace
        track_locations
        analyze
        action_view_helpers
        transform_conditionals
        render_nodes
        strict_locals
        iteration_nodes
      ].freeze

      module_function

      def parse(source, options_hash = {})
        result = Herb.parse(source, **forwardable(options_hash))

        {
          value: result.value,
          source: result.source,
          warnings: result.warnings,
          errors: result.errors,
          options: result.options.to_h,
        }.to_json
      end

      def lex(source)
        result = Herb.lex(source)

        {
          value: result.value,
          source: result.source,
          warnings: result.warnings,
          errors: result.errors,
        }.to_json
      end

      def forwardable(options_hash)
        options_hash.each_with_object({}) do |(key, value), forwarded|
          symbol_key = key.to_sym
          forwarded[symbol_key] = value if FORWARDABLE_OPTIONS.include?(symbol_key)
        end
      end
      private_class_method :forwardable
    end
  end
end
