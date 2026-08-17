# frozen_string_literal: true

require "json"
require "prism"
require_relative "engine_adapter"
require_relative "result_envelope"
require_relative "diagnostic"

module Herb
  module Embedded
    # Boots the JS engine: loads the host shim and vendored bundle,
    # attaches the six Ruby callbacks HerbBackend needs, then loads the
    # RubyBackend subclass and waits for its async init to resolve.
    class Bridge
      class VersionMismatchError < StandardError; end
      class NotBootedError < StandardError; end

      HOST_SHIM_PATH = File.expand_path("../../../js/host_shim.js", __dir__)
      RUBY_BACKEND_PATH = File.expand_path("../../../js/ruby_backend.js", __dir__)

      READY_CHECK_JS = <<~JS
        function __herbEmbeddedReady() { return __herbEmbeddedBridge.ready; }
        function __herbEmbeddedError() { return __herbEmbeddedBridge.error; }
        function __herbEmbeddedVersion() { return __herbEmbeddedBridge.instance.version; }
      JS

      def initialize(adapter:, bundle:)
        @adapter = adapter
        @bundle = bundle
        @booted = false
      end

      def boot
        # Herb is pre-1.0: the major version never moves (0.8 -> 0.9 -> 0.10
        # are all "0"), so semver-range gating can't distinguish a validated
        # version from an unvalidated one. Gate on the recorded set instead.
        unless @bundle.herb_versions.include?(::Herb::VERSION)
          raise VersionMismatchError,
                "herb #{::Herb::VERSION} has not been validated against this bundle " \
                "(validated versions: #{@bundle.herb_versions.join(", ")})"
        end

        @adapter.load(File.read(HOST_SHIM_PATH))
        @adapter.load(@bundle.source)
        attach_callbacks
        @adapter.load(File.read(RUBY_BACKEND_PATH))
        @adapter.load(READY_CHECK_JS)

        unless @adapter.call("__herbEmbeddedReady")
          raise "Bridge failed to boot: #{@adapter.call("__herbEmbeddedError")}"
        end

        @booted = true
        self
      end

      def backend_version
        ensure_booted!
        @adapter.call("__herbEmbeddedVersion")
      end

      def rule_names
        ensure_booted!
        @adapter.call("__herbRuleNames")
      end

      def lint(source, file:, rules: nil)
        ensure_booted!
        offenses = JSON.parse(@adapter.call("__herbLint", source, file, rules))
        offenses.map { |offense| Diagnostic.from_js(offense, file: file) }
      end

      def register_custom_rule(source, path)
        ensure_booted!
        @adapter.call("__herbRegisterCustomRule", source, path)
      end

      # A formatter-adjacent tool must never write source that fails to
      # parse into a user's working tree. If the fixed output fails to
      # parse while the original input parsed cleanly, the fix is
      # discarded rather than trusted.
      def autofix(source, file:, rules: nil, unsafe: false)
        ensure_booted!
        raw = JSON.parse(@adapter.call("__herbAutofix", source, file, rules, unsafe))

        if source_parses?(source) && !source_parses?(raw["source"])
          return { source: source, applied: [], discarded: true }
        end

        applied = raw["fixed"].map { |offense| Diagnostic.from_js(offense, file: file) }
        { source: raw["source"], applied: applied, discarded: false }
      end

      def dispose
        @adapter.dispose
      end

      private

      def ensure_booted!
        raise NotBootedError, "Bridge#boot must be called before this method" unless @booted
      end

      def attach_callbacks
        @adapter.attach("rbParse") { |source, options| ResultEnvelope.parse(source, options || {}) }
        @adapter.attach("rbLex") { |source| ResultEnvelope.lex(source) }
        @adapter.attach("rbExtractRuby") { |source, options| ::Herb.extract_ruby(source, **symbolize(options)) }
        @adapter.attach("rbExtractHTML") { |source| ::Herb.extract_html(source) }
        @adapter.attach("rbParseRuby") { |source| EngineAdapter.binary(::Prism.dump(source)) }
        @adapter.attach("rbVersion") { ::Herb.version }
      end

      def symbolize(hash)
        (hash || {}).transform_keys(&:to_sym)
      end

      def source_parses?(source)
        JSON.parse(ResultEnvelope.parse(source, {}))["errors"].empty?
      end
    end
  end
end
