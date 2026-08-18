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
      # forwarding that through raises JSON::GeneratorError. Both are
      # instead handled below by computing JSON-safe byte arrays
      # ourselves. Also excludes timeout and max_errors (timing/error-cap
      # options, not shape).
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
        envelope = build_envelope(source, options_hash)

        return envelope.to_json unless options_hash[:prism_nodes] || options_hash[:prism_nodes_deep]

        with_injected_prism_nodes(envelope, source)
      end

      def build_envelope(source, options_hash)
        result = Herb.parse(source, **forwardable(options_hash))

        value_hash = result.value.to_hash
        value_hash[:prism_node] = prism_program_bytes(source) if options_hash[:prism_program]

        {
          value: value_hash,
          source: result.source,
          warnings: result.warnings,
          errors: result.errors,
          options: result.options.to_h,
        }
      end
      private_class_method :build_envelope

      def lex(source)
        result = Herb.lex(source)

        {
          tokens: result.value,
          source: result.source,
          warnings: result.warnings,
          errors: result.errors,
        }.to_json
      end

      # value_hash's children are still live Herb::AST::Node objects
      # (#to_hash is shallow), so per-node injection needs them as plain
      # Hashes first. A JSON round-trip is the simplest way to get that
      # without hand-walking Node#child_nodes ourselves.
      def with_injected_prism_nodes(envelope, source)
        parsed_envelope = JSON.parse(envelope.to_json)
        inject_prism_nodes(parsed_envelope["value"], source)
        parsed_envelope.to_json
      end
      private_class_method :with_injected_prism_nodes

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

      # Every AST_ERB_* node (ERBContentNode, ERBBlockNode, ERBIfNode,
      # ...) carries its own embedded-Ruby snippet in a `content` token
      # with a byte `range` into the whole file. Unlike prism_program's
      # single whole-document parse, each of these needs its own Prism
      # parse scoped to just that snippet — but still offset-correct
      # against the whole-file `source`, since that's what every
      # ERB*Node#prismNode getter deserializes against (ruby_backend.js
      # unwraps the resulting single-statement ProgramNode down to the
      # inner expression node the vendored rules actually expect).
      def inject_prism_nodes(node, source)
        case node
        when Hash
          inject_prism_node_for(node, source)
          node.each_value { |value| inject_prism_nodes(value, source) }
        when Array
          node.each { |value| inject_prism_nodes(value, source) }
        end
      end
      private_class_method :inject_prism_nodes

      def inject_prism_node_for(node, source)
        return unless node["type"].is_a?(String) && node["type"].start_with?("AST_ERB_")

        range = node.dig("content", "range")
        return unless range.is_a?(Array) && range.length == 2

        node["prism_node"] = prism_nodes_bytes(source, range[0], range[1])
      end
      private_class_method :inject_prism_node_for

      # Blanks (space, newlines preserved) every byte outside [from, to)
      # so the one node's own Ruby content parses alone — at the correct
      # absolute offset — rather than pulling in unrelated HTML or other
      # ERB tags' Ruby.
      def prism_nodes_bytes(source, from, to)
        bytes = source.b.bytes
        bytes.each_index do |i|
          next if i >= from && i < to

          bytes[i] = 0x20 unless bytes[i] == 0x0A
        end

        Prism.dump(bytes.pack("C*").force_encoding(source.encoding)).bytes
      end
      private_class_method :prism_nodes_bytes
    end
  end
end
