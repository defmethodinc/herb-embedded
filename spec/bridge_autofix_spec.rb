# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/bridge"
require "herb/embedded/bundle"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::Bridge do
  let(:adapter) { Herb::Embedded::Adapters::MiniRacer.new }
  let(:bridge) { described_class.new(adapter: adapter, bundle: Herb::Embedded::Bundle).boot }

  after { adapter.dispose }

  it "fixes a safe autocorrectable offense, reports it under applied, and clears it on re-lint" do
    source = "<div>hi</div>   \n"

    result = bridge.autofix(source, file: "x.html.erb", rules: ["erb-no-trailing-whitespace"])

    expect(result[:source]).to eq("<div>hi</div>\n")
    expect(result[:applied].map(&:rule)).to eq(["erb-no-trailing-whitespace"])
    expect(result[:discarded]).to be(false)

    remaining = bridge.lint(result[:source], file: "x.html.erb", rules: ["erb-no-trailing-whitespace"])
    expect(remaining).to be_empty
  end

  it "leaves an uncorrectable offense untouched in the returned source" do
    bridge

    adapter.load(<<~JS)
      class FakeUncorrectableRule extends HerbLinter.SourceRule {
        static ruleName = "fake-uncorrectable-rule";
        check(source, context) {
          return [this.createOffense("fake offense", { start: { line: 1, column: 0 }, end: { line: 1, column: 1 } })];
        }
      }
      HerbLinter.rules.push(FakeUncorrectableRule);
    JS

    source = "<div>hi</div>\n"
    result = bridge.autofix(source, file: "x.html.erb", rules: ["fake-uncorrectable-rule"])

    expect(result[:source]).to eq(source)
    expect(result[:applied]).to be_empty
    expect(result[:discarded]).to be(false)
  end

  it "discards a fix that breaks parsing, keeping the original source" do
    bridge

    adapter.load(<<~JS)
      class FakeBreakingRule extends HerbLinter.SourceRule {
        static ruleName = "fake-breaking-rule";
        static autocorrectable = true;
        check(source, context) {
          return [this.createOffense("fake offense", { start: { line: 1, column: 0 }, end: { line: 1, column: 1 } })];
        }
        autofix(offense, source, context) {
          return "<div>";
        }
      }
      HerbLinter.rules.push(FakeBreakingRule);
    JS

    source = "<div>hi</div>\n"
    result = bridge.autofix(source, file: "x.html.erb", rules: ["fake-breaking-rule"])

    expect(result[:source]).to eq(source)
    expect(result[:applied]).to be_empty
    expect(result[:discarded]).to be(true)
  end

  it "unsafe: false skips unsafe fixes; unsafe: true applies them" do
    bridge

    adapter.load(<<~JS)
      class FakeUnsafeRule extends HerbLinter.SourceRule {
        static ruleName = "fake-unsafe-rule";
        static autocorrectable = true;
        static unsafeAutocorrectable = true;
        check(source, context) {
          return [this.createOffense("fake offense", { start: { line: 1, column: 0 }, end: { line: 1, column: 1 } })];
        }
        autofix(offense, source, context) {
          return source.replace("hi", "bye");
        }
      }
      HerbLinter.rules.push(FakeUnsafeRule);
    JS

    source = "<div>hi</div>\n"

    safe_result = bridge.autofix(source, file: "x.html.erb", rules: ["fake-unsafe-rule"], unsafe: false)
    expect(safe_result[:source]).to eq(source)
    expect(safe_result[:applied]).to be_empty

    unsafe_result = bridge.autofix(source, file: "x.html.erb", rules: ["fake-unsafe-rule"], unsafe: true)
    expect(unsafe_result[:source]).to eq("<div>bye</div>\n")
    expect(unsafe_result[:applied].map(&:rule)).to eq(["fake-unsafe-rule"])
  end
end
