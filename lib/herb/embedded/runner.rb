# frozen_string_literal: true

require "pathname"
require_relative "report"
require_relative "lint_result"
require_relative "custom_rule_loader"

module Herb
  module Embedded
    # The Ruby replacement for cli.js's filesystem role: discovers files,
    # iterates, and aggregates results. Formatters are pure functions of
    # the Report this produces.
    class Runner
      def initialize(root:, config:, bridge:)
        @root = root
        @config = config
        @bridge = bridge
        @custom_rules_loaded = false
      end

      def run(paths = nil, rules: nil)
        load_custom_rules!

        Report.new.tap do |report|
          files_for(paths).each do |absolute_path|
            file = relative_path(absolute_path)
            diagnostics = @bridge.lint(File.read(absolute_path), file: file, rules: rules)
            report.add(LintResult.new(file: file, diagnostics: diagnostics))
          end
        end
      end

      def fix(paths = nil, rules: nil, unsafe: false)
        load_custom_rules!

        Report.new.tap do |report|
          files_for(paths).each do |absolute_path|
            file = relative_path(absolute_path)
            original_source = File.read(absolute_path)
            result = @bridge.autofix(original_source, file: file, rules: rules, unsafe: unsafe)

            File.write(absolute_path, result[:source]) if result[:source] != original_source

            diagnostics = @bridge.lint(result[:source], file: file, rules: rules)
            report.add(LintResult.new(file: file, diagnostics: diagnostics))
          end
        end
      end

      # Idempotent and safe to call ahead of #run/#fix — e.g. so a caller
      # can validate rule names (like a CLI's --only flag) against
      # Bridge#rule_names with custom rules already registered.
      def load_custom_rules!
        return if @custom_rules_loaded

        CustomRuleLoader.new(root: @root, bridge: @bridge).load_all
        @custom_rules_loaded = true
      end

      private

      def files_for(paths)
        return discover_files unless paths

        paths.map { |path| File.expand_path(path, @root) }
      end

      def discover_files
        included = @config.include_globs.flat_map { |glob| Dir.glob(File.join(@root, glob)) }
        excluded = @config.exclude_globs.flat_map { |glob| Dir.glob(File.join(@root, glob)) }
        (included - excluded).sort
      end

      def relative_path(absolute_path)
        Pathname.new(absolute_path).relative_path_from(Pathname.new(@root)).to_s
      end
    end
  end
end
