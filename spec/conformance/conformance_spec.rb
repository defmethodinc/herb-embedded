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

  def reference_offenses(fixture_path)
    stdout, stderr, status = Open3.capture3(
      CONFORMANCE_REFERENCE_LINTER, fixture_path, "--json", "--no-custom-rules", "--no-color", "--jobs", "1",
      chdir: CONFORMANCE_ROOT
    )
    unless status.exitstatus.zero? || status.exitstatus == 1
      raise "reference herb-lint failed (exit #{status.exitstatus}): #{stderr}"
    end

    if stdout.strip.empty?
      raise "reference herb-lint produced no output (exit #{status.exitstatus}); stderr: #{stderr.empty? ? "(empty)" : stderr}"
    end

    JSON.parse(stdout)["offenses"].map { |o| [o["code"], o["location"]["start"]["line"], o["location"]["start"]["column"]] }
  end

  def bridge_offenses(fixture_path)
    source = File.read(fixture_path)
    bridge.lint(source, file: File.basename(fixture_path)).map { |d| [d.rule, d.line, d.column] }
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
end
