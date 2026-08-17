# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "herb/embedded/custom_rule_loader"
require "herb/embedded/bridge"
require "herb/embedded/bundle"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::CustomRuleLoader do
  let(:adapter) { Herb::Embedded::Adapters::MiniRacer.new }
  let(:bridge) { Herb::Embedded::Bridge.new(adapter: adapter, bundle: Herb::Embedded::Bundle).boot }

  after { adapter.dispose }

  def write_rule(dir, filename, contents)
    rules_dir = File.join(dir, ".herb", "rules")
    FileUtils.mkdir_p(rules_dir)
    File.write(File.join(rules_dir, filename), contents)
  end

  let(:custom_rule_source) do
    <<~JS
      import { ParserRule } from "@herb-tools/linter";

      export default class MyCustomRule extends ParserRule {
        static ruleName = "my-custom-rule";

        check(result, context) {
          return [this.createOffense("Custom offense!", result.value.location)];
        }
      }
    JS
  end

  it "loads .herb/rules/**/*.mjs, registers each rule, and returns their names" do
    Dir.mktmpdir do |dir|
      write_rule(dir, "my_custom_rule.mjs", custom_rule_source)

      names = described_class.new(root: dir, bridge: bridge).load_all

      expect(names).to eq(["my-custom-rule"])
    end
  end

  it "produces real offenses and composes with built-in rules in the same Bridge#lint run" do
    Dir.mktmpdir do |dir|
      write_rule(dir, "my_custom_rule.mjs", custom_rule_source)
      described_class.new(root: dir, bridge: bridge).load_all

      source = %(<div  class="a">x</div>)
      diagnostics = bridge.lint(source, file: "x.html.erb", rules: %w[my-custom-rule html-no-space-in-tag])

      expect(diagnostics.map(&:rule)).to contain_exactly("my-custom-rule", "html-no-space-in-tag")
    end
  end

  it "raises UnsupportedImportError naming the file and the offending specifier" do
    Dir.mktmpdir do |dir|
      bad_rule = <<~JS
        import fs from "fs";

        export default class Bad {
          static ruleName = "bad-rule";
          check() { return []; }
        }
      JS
      write_rule(dir, "bad.mjs", bad_rule)

      error = nil
      begin
        described_class.new(root: dir, bridge: bridge).load_all
      rescue described_class::UnsupportedImportError => e
        error = e
      end

      expect(error).not_to be_nil
      expect(error.message).to match(/bad\.mjs/)
      expect(error.message).to match(/"fs"/)
    end
  end

  it "raises InvalidRuleError naming the file when there is no default export" do
    Dir.mktmpdir do |dir|
      write_rule(dir, "no_export.mjs", "const x = 1;\n")

      expect { described_class.new(root: dir, bridge: bridge).load_all }
        .to raise_error(described_class::InvalidRuleError, /no_export\.mjs/)
    end
  end

  it "a custom rule sharing a built-in's ruleName replaces it and warns to stderr" do
    Dir.mktmpdir do |dir|
      overriding_rule = <<~JS
        import { ParserRule } from "@herb-tools/linter";

        export default class Override extends ParserRule {
          static ruleName = "html-no-space-in-tag";
          check(result, context) { return []; }
        }
      JS
      write_rule(dir, "override.mjs", overriding_rule)

      before_count = bridge.rule_names.size

      expect { described_class.new(root: dir, bridge: bridge).load_all }
        .to output(/html-no-space-in-tag/).to_stderr

      expect(bridge.rule_names.size).to eq(before_count)
    end
  end

  it "returns [] without error for an empty or missing .herb/rules/ directory" do
    Dir.mktmpdir do |dir|
      expect(described_class.new(root: dir, bridge: bridge).load_all).to eq([])

      FileUtils.mkdir_p(File.join(dir, ".herb", "rules"))
      expect(described_class.new(root: dir, bridge: bridge).load_all).to eq([])
    end
  end
end
