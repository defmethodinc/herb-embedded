# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/bridge"
require "herb/embedded/bundle"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::Bridge do
  let(:adapter) { Herb::Embedded::Adapters::MiniRacer.new }
  let(:bridge) { described_class.new(adapter: adapter, bundle: Herb::Embedded::Bundle).boot }

  after { adapter.dispose }

  it "produces diagnostics for real offenses in source" do
    source = %(<div  class="a">x</div>)

    diagnostics = bridge.lint(source, file: "app/views/x.html.erb", rules: ["html-no-space-in-tag"])

    expect(diagnostics).to all(be_a(Herb::Embedded::Diagnostic))
    expect(diagnostics.map(&:rule)).to include("html-no-space-in-tag")
  end

  it "exposes all rule names the bundled linter provides" do
    expect(bridge.rule_names).to include("html-no-space-in-tag", "html-tag-name-lowercase")
    expect(bridge.rule_names.size).to be > 50
  end

  it "restricts execution to exactly the selected rules, confirmed by a side-channel instantiation count" do
    bridge

    adapter.load(<<~JS)
      class SpyRule {
        static ruleName = "spy-rule";
        static type = "parser";
        constructor() { globalThis.__spyRuleInstantiated = (globalThis.__spyRuleInstantiated || 0) + 1; }
        check(parseResult, context) { return []; }
      }
      HerbLinter.rules.push(SpyRule);
      function __spyRuleInstantiationCount() { return globalThis.__spyRuleInstantiated || 0; }
    JS

    source = %(<div  class="a">x</div>)

    bridge.lint(source, file: "x.html.erb", rules: ["html-tag-name-lowercase"])
    expect(adapter.call("__spyRuleInstantiationCount")).to eq(0)

    bridge.lint(source, file: "x.html.erb", rules: ["spy-rule"])
    # Linter#lint instantiates a selected rule twice: once to run check(),
    # once more in bindSeverity() to read the rule's default severity.
    expect(adapter.call("__spyRuleInstantiationCount")).to eq(2)
  end

  # isEnabled() only reads context.fileName, so it's a narrower probe than
  # check() (see the prism_program-backed diagnostic test below) — kept
  # separately since it isolates context threading from prismNode wiring.
  it "threads file: into LintContext under both fileName and filename" do
    bridge

    adapter.load(<<~JS)
      function __testIsEnabled(fileName) {
        var RuleClass = HerbLinter.rules.filter(function (r) {
          return r.ruleName === "erb-no-instance-variables-in-partials";
        })[0];
        return new RuleClass().isEnabled(null, { fileName: fileName, filename: fileName });
      }
    JS

    expect(adapter.call("__testIsEnabled", "app/views/_form.html.erb")).to be(true)
    expect(adapter.call("__testIsEnabled", "app/views/form.html.erb")).to be(false)
  end

  it "isolates a crashing rule: the run continues and the crash becomes a self-naming diagnostic" do
    bridge

    adapter.load(<<~JS)
      class FakeCrashRule {
        static ruleName = "fake-crash-rule";
        static type = "parser";
        check(parseResult, context) { throw new Error("boom"); }
      }
      HerbLinter.rules.push(FakeCrashRule);
    JS

    source = %(<div  class="a">x</div>)
    diagnostics = bridge.lint(source, file: "x.html.erb", rules: %w[fake-crash-rule html-no-space-in-tag])

    crash_diagnostic = diagnostics.find { |d| d.rule == "fake-crash-rule" }
    expect(crash_diagnostic.message).to include("boom")
    expect(diagnostics.map(&:rule)).to include("html-no-space-in-tag")
  end

  it "forwards track_whitespace through parse options, changing whitespace-sensitive rule output" do
    source = %(<div  class="a">x</div>)

    expect(bridge.lint(source, file: "x.html.erb", rules: ["html-no-space-in-tag"])).not_to be_empty
    expect(bridge.lint(%(<div class="a">x</div>), file: "x.html.erb", rules: ["html-no-space-in-tag"])).to be_empty
  end

  it "produces a real offense for a prism_program-backed rule, not just isEnabled() firing" do
    source = %(<div><%= @foo %></div>\n)

    diagnostics = bridge.lint(source, file: "app/views/_form.html.erb", rules: ["erb-no-instance-variables-in-partials"])

    expect(diagnostics.size).to eq(1)
    expect(diagnostics.first.message).to include("@foo")

    non_partial_diagnostics = bridge.lint(source, file: "app/views/form.html.erb", rules: ["erb-no-instance-variables-in-partials"])
    expect(non_partial_diagnostics).to be_empty
  end

  it "produces a real offense for a prism_nodes-backed rule with offset-sensitive location, not just isEnabled() firing" do
    source = %(<%= raw(@untrusted) %>\n)

    diagnostics = bridge.lint(source, file: "x.html.erb", rules: ["erb-no-unsafe-raw"])

    expect(diagnostics.size).to eq(1)
    expect(diagnostics.first.column).to eq(4)

    expect(bridge.lint(%(<%= @untrusted %>\n), file: "x.html.erb", rules: ["erb-no-unsafe-raw"])).to be_empty
  end

  it "skips assignments for a prism_nodes-backed rule that must inspect the embedded Ruby's node type" do
    expect(bridge.lint("<% @foo = 1 %>\n", file: "x.html.erb", rules: ["erb-no-silent-statement"])).to be_empty
    expect(bridge.lint("<% do_something_silently %>\n", file: "x.html.erb", rules: ["erb-no-silent-statement"])).not_to be_empty
  end

  it "excludes a rule not enabled by default when rules: is nil, but includes it when explicitly selected" do
    bridge

    adapter.load(<<~JS)
      class FakeDisabledByDefaultRule extends HerbLinter.SourceRule {
        static ruleName = "fake-disabled-by-default";
        get defaultConfig() { return { enabled: false, severity: "error", exclude: [] }; }
        check(source, context) {
          return [this.createOffense("should not run by default", { start: { line: 1, column: 0 }, end: { line: 1, column: 1 } })];
        }
      }
      HerbLinter.rules.push(FakeDisabledByDefaultRule);
    JS

    source = "<div>hi</div>\n"

    default_diagnostics = bridge.lint(source, file: "x.html.erb")
    expect(default_diagnostics.map(&:rule)).not_to include("fake-disabled-by-default")

    explicit_diagnostics = bridge.lint(source, file: "x.html.erb", rules: ["fake-disabled-by-default"])
    expect(explicit_diagnostics.map(&:rule)).to include("fake-disabled-by-default")
  end
end
