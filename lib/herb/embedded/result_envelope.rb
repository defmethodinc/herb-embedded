# frozen_string_literal: true

require "herb"
require "json"
require "prism"

module Herb
  module Embedded
    # Herb::ParseResult#to_json returns an inspect string, not the wire
    # format @herb-tools/core's ParseResult.from() expects. This builds
    # that envelope by hand from the pieces that do serialize correctly.
    module ResultEnvelope
      # Allowlist of Herb::ParserOptions keys safe to forward from
      # caller-supplied options. Deliberately excludes prism_nodes,
      # prism_nodes_deep, and prism_program: asking Herb.parse itself to
      # embed prism_node populates it with a raw ASCII-8BIT String, and
      # forwarding that through raises JSON::GeneratorError. prism_program
      # is instead handled below by computing a JSON-safe byte array
      # ourselves; prism_nodes/prism_nodes_deep (per-ERBContentNode
      # injection) remain unimplemented — see CHARTER.md. Also excludes
      # timeout and max_errors (timing/error-cap options, not shape).
      FORWARDABLE_OPTIONS = %i[
        strict
        track_whitespace
        analyze
        action_view_helpers
        transform_conditionals
        render_nodes
        strict_locals
      ].freeze

      module_function

      def parse(source, options_hash = {})
        options_hash = (options_hash || {}).transform_keys(&:to_sym)
        result = Herb.parse(source, **forwardable(options_hash))

        value_hash = result.value.to_hash
        value_hash[:prism_node] = prism_program_bytes(source) if options_hash[:prism_program]

        {
          value: value_hash,
          source: result.source,
          warnings: result.warnings,
          errors: result.errors,
          options: result.options.to_h,
        }.to_json
      end

      def lex(source)
        result = Herb.lex(source)

        {
          tokens: result.value,
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

      # @herb-tools/core's DocumentNode#prismNode getter deserializes
      # prism_node bytes against the node's own (whole-file) `source`, so
      # the bytes must come from parsing something byte-length-identical
      # to source with Ruby content at the same offsets — exactly what
      # Herb.extract_ruby produces (non-Ruby content blanked, not
      # stripped). A plain Array of bytes (not the ASCII-8BIT String
      # Prism.dump returns) is what keeps this JSON-safe.
      def prism_program_bytes(source)
        Prism.dump(Herb.extract_ruby(source)).bytes
      end
      private_class_method :prism_program_bytes
    end
  end
end
