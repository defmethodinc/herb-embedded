# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "herb/embedded/bridge"
require "herb/embedded/bundle"
require "herb/embedded/adapters/mini_racer"

CONFORMANCE_ROOT = File.expand_path("../..", __dir__)
CONFORMANCE_REFERENCE_LINTER = File.join(CONFORMANCE_ROOT, "node_modules", ".bin", "herb-lint")
CONFORMANCE_FIXTURES = Dir.glob(File.join(__dir__, "fixtures", "*.html.erb"))
CONFORMANCE_RULE_FIXTURES = Dir.glob(File.join(__dir__, "fixtures", "rules", "*.html.erb"))

# A handful of rules (erb-no-instance-variables-in-partials and friends)
# only enable themselves for partial files (basename starting with `_`),
# so their fixture is named with that leading underscore to trigger
# correctly — this strips it back off to recover the rule code the
# coverage-gate test and --only/rules: need. Top-level (not an instance
# method) since it's needed both at spec-definition time, to build each
# `it` description, and at example-run time.
def conformance_rule_name_for(fixture_path)
  File.basename(fixture_path, ".html.erb").sub(/\A_/, "")
end

# Node at test time is acceptable — the guarantee this repo makes is
# about *user* time (see spec/no_node_spec.rb). This is the differential
# backstop against silent AST drift: if a future herb gem release
# changes node shapes, rules don't crash, they quietly stop matching.
# This test is what turns that into a loud, named failure instead of a
# green run that's secretly broken.
RSpec.describe "Conformance against npx @herb-tools/linter" do
  let(:adapter) { Herb::Embedded::Adapters::MiniRacer.new }
  let(:bridge) { Herb::Embedded::Bridge.new(adapter: adapter, bundle: Herb::Embedded::Bundle).boot }

  after { adapter.dispose }

  def reference_offenses(fixture_path, only: nil)
    # --no-github: herb-lint auto-enables GitHub Actions annotations whenever
    # GITHUB_ACTIONS=true is set (i.e. inside our own CI job), which then
    # conflicts fatally with --json ("--github cannot be used with --json
    # format"). Explicitly disabling it makes --json behavior independent of
    # the invoking environment.
    #
    # --only ignores .herb.yml config entirely (including a rule's own
    # defaultConfig.enabled), matching rules: [...] on the bridge side —
    # both let a per-rule fixture exercise a not-enabled-by-default rule
    # directly, the same way gu7/ada's Bridge#lint specs already do.
    args = [
      CONFORMANCE_REFERENCE_LINTER, fixture_path, "--json", "--no-custom-rules", "--no-color", "--no-github",
      "--jobs", "1"
    ]
    args += ["--only", only] if only

    stdout, stderr, status = Open3.capture3(*args, chdir: CONFORMANCE_ROOT)
    unless status.exitstatus.zero? || status.exitstatus == 1
      raise "reference herb-lint failed (exit #{status.exitstatus}): #{stderr}"
    end

    if stdout.strip.empty?
      raise "reference herb-lint produced no output (exit #{status.exitstatus}); stderr: #{stderr.empty? ? "(empty)" : stderr}"
    end

    JSON.parse(stdout)["offenses"].map { |o| [o["code"], o["location"]["start"]["line"], o["location"]["start"]["column"]] }
  end

  def bridge_offenses(fixture_path, rules: nil)
    source = File.read(fixture_path)
    bridge.lint(source, file: File.basename(fixture_path), rules: rules).map { |d| [d.rule, d.line, d.column] }
  end

  CONFORMANCE_FIXTURES.each do |fixture_path|
    it "matches npx @herb-tools/linter offense-for-offense on #{File.basename(fixture_path)}" do
      reference = reference_offenses(fixture_path).sort
      actual = bridge_offenses(fixture_path).sort

      missing = reference - actual
      extra = actual - reference

      expect([missing, extra]).to eq([[], []]), <<~MSG
        Conformance mismatch for #{File.basename(fixture_path)} — [rule, line, column] tuples:
          Missing (npx found it, bridge did not): #{missing.inspect}
          Extra   (bridge found it, npx did not): #{extra.inspect}
      MSG
    end
  end

  it "has at least the minimum required fixtures" do
    required = %w[basic whitespace erb_ruby non_ascii parse_errors]
    present = CONFORMANCE_FIXTURES.map { |f| File.basename(f, ".html.erb") }

    expect(present).to include(*required)
  end

  CONFORMANCE_RULE_FIXTURES.each do |fixture_path|
    rule = conformance_rule_name_for(fixture_path)

    it "matches npx @herb-tools/linter offense-for-offense on the #{rule} fixture, exercising the rule" do
      reference = reference_offenses(fixture_path, only: rule).sort
      actual = bridge_offenses(fixture_path, rules: [rule]).sort

      expect(reference).not_to be_empty,
                               "Fixture #{File.basename(fixture_path)} produced no reference offenses for " \
                               "#{rule} — it doesn't actually trigger the rule"

      missing = reference - actual
      extra = actual - reference

      expect([missing, extra]).to eq([[], []]), <<~MSG
        Conformance mismatch for #{rule} (#{File.basename(fixture_path)}) — [rule, line, column] tuples:
          Missing (npx found it, bridge did not): #{missing.inspect}
          Extra   (bridge found it, npx did not): #{extra.inspect}
      MSG
    end
  end

  it "has a conformance fixture for every rule the vendored bundle registers" do
    registered = bridge.rule_names
    covered = CONFORMANCE_RULE_FIXTURES.map { |f| conformance_rule_name_for(f) }

    missing = registered - covered
    expect(missing).to be_empty,
                       "Rules registered by the vendored bundle with no conformance fixture under " \
                       "spec/conformance/fixtures/rules/: #{missing.sort.inspect}"
  end
end
