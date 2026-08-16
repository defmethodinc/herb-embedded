# frozen_string_literal: true

require "yaml"

module Herb
  module Embedded
    # Reads .herb.yml. The engine has no filesystem, so Ruby owns config
    # entirely. Uses the same nested schema as upstream @herb-tools/config
    # (only version, files.include/exclude, linter.fail_level, and
    # linter.rules.<name>.enabled are read; other upstream keys are
    # parsed as inert and ignored, not errored on).
    class Config
      CONFIG_FILENAME = ".herb.yml"
      DEFAULT_INCLUDE_GLOBS = ["**/*.html.erb", "**/*.herb"].freeze
      DEFAULT_EXCLUDE_GLOBS = [].freeze
      DEFAULT_FAIL_LEVEL = :error

      attr_reader :include_globs, :exclude_globs, :fail_level, :linter_version

      def self.load(dir)
        path = File.join(dir, CONFIG_FILENAME)
        data = File.exist?(path) ? (YAML.load_file(path) || {}) : {}

        new(data)
      end

      def initialize(data)
        files = data["files"] || {}
        linter = data["linter"] || {}

        @include_globs = files["include"] || DEFAULT_INCLUDE_GLOBS.dup
        @exclude_globs = files["exclude"] || DEFAULT_EXCLUDE_GLOBS.dup
        @fail_level = (linter["fail_level"] || DEFAULT_FAIL_LEVEL).to_sym
        @linter_version = data["version"]
        @disabled_rule_names = disabled_rule_names(linter["rules"])
      end

      def enabled_rule_names(all_rule_names)
        all_rule_names - @disabled_rule_names
      end

      private

      def disabled_rule_names(rules)
        (rules || {}).each_with_object([]) do |(name, rule_config), disabled|
          disabled << name if rule_config.is_a?(Hash) && rule_config["enabled"] == false
        end
      end
    end
  end
end
