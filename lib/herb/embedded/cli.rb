# frozen_string_literal: true

require "optparse"
require "yaml"
require_relative "version"
require_relative "bundle"
require_relative "config"
require_relative "bridge"
require_relative "runner"
require_relative "formatters"
require_relative "adapters/mini_racer"

module Herb
  module Embedded
    # The user-facing entry point (exe/herb-lint-rb). Flags mirror
    # herb-lint; the -rb suffix lets both binaries coexist.
    class CLI
      EXIT_CLEAN = 0
      EXIT_OFFENSES = 1
      EXIT_CONFIG_ERROR = 2

      VALID_FORMATS = %w[detailed simple json github].freeze
      VALID_FAIL_LEVELS = %w[error warning info hint].freeze

      HERB_YML_TEMPLATE = <<~YAML
        version: "%<version>s"
        files:
          include:
            - "**/*.html.erb"
            - "**/*.herb"
          exclude: []
        linter:
          fail_level: error
          rules: {}
      YAML

      def initialize(argv, stdout:, stderr:)
        @argv = argv.dup
        @stdout = stdout
        @stderr = stderr
        @format = "detailed"
        @fail_level = nil
        @only = []
        @fix = false
        @unsafe = false
        @mode = :lint
      end

      def run
        parser.parse!(@argv)

        case @mode
        when :help
          @stdout.puts parser.help
          EXIT_CLEAN
        when :version
          print_version
        when :init
          write_init_file
        else
          lint_and_report
        end
      rescue OptionParser::ParseError => e
        @stderr.puts e.message
        EXIT_CONFIG_ERROR
      rescue Psych::SyntaxError => e
        @stderr.puts "Invalid .herb.yml: #{e.message}"
        EXIT_CONFIG_ERROR
      end

      private

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: herb-lint-rb [options] [files...]"

          define_fix_options(opts)
          define_report_options(opts)
          define_mode_options(opts)
        end
      end

      def define_fix_options(opts)
        opts.on("--fix", "Apply safe autocorrections") { @fix = true }
        opts.on("--fix-unsafely", "Apply unsafe autocorrections too") do
          @fix = true
          @unsafe = true
        end
      end

      def define_report_options(opts)
        opts.on("--format FORMAT", VALID_FORMATS, "detailed | simple | json | github (default: detailed)") do |v|
          @format = v
        end
        opts.on("--fail-level LEVEL", VALID_FAIL_LEVELS, "error | warning | info | hint") do |v|
          @fail_level = v.to_sym
        end
        opts.on("--only RULE", "Run only this rule (repeatable)") { |v| @only << v }
      end

      def define_mode_options(opts)
        opts.on("--init", "Write .herb.yml pinning the current linter version") { @mode = :init }
        opts.on("--version", "Print herb-embedded and bundled @herb-tools/linter versions") { @mode = :version }
        opts.on("-h", "--help", "Show this help") { @mode = :help }
      end

      def print_version
        @stdout.puts "herb-embedded #{Herb::Embedded::VERSION} (bundled @herb-tools/linter #{Bundle.linter_version})"
        EXIT_CLEAN
      end

      def write_init_file
        path = File.join(Dir.pwd, ".herb.yml")
        File.write(path, format(HERB_YML_TEMPLATE, version: Bundle.linter_version))
        @stdout.puts "Wrote #{path}"
        EXIT_CLEAN
      end

      def lint_and_report
        root = Dir.pwd
        config = Config.load(root)
        bridge, runner = boot_bridge_and_runner(root, config)

        unknown_rules = @only - bridge.rule_names
        return report_unknown_rules(unknown_rules) if unknown_rules.any?

        report = run_or_fix(runner)
        @stdout.puts Formatters.fetch(@format.to_sym).render(report)
        report.exit_code(fail_level: @fail_level || config.fail_level)
      ensure
        bridge&.dispose
      end

      def boot_bridge_and_runner(root, config)
        bridge = Bridge.new(adapter: Adapters::MiniRacer.new, bundle: Bundle).boot
        runner = Runner.new(root: root, config: config, bridge: bridge)
        runner.load_custom_rules!
        [bridge, runner]
      end

      def report_unknown_rules(unknown_rules)
        @stderr.puts "Unknown rule(s): #{unknown_rules.join(", ")}"
        EXIT_CONFIG_ERROR
      end

      def run_or_fix(runner)
        paths = @argv.empty? ? nil : @argv
        rules = @only.empty? ? nil : @only

        if @fix
          runner.fix(paths, rules: rules, unsafe: @unsafe)
        else
          runner.run(paths, rules: rules)
        end
      end
    end
  end
end
