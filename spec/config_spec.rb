# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "herb/embedded/config"

RSpec.describe Herb::Embedded::Config do
  def with_herb_yml(contents)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".herb.yml"), contents) if contents
      yield dir
    end
  end

  describe ".load" do
    it "returns documented defaults when .herb.yml is absent" do
      with_herb_yml(nil) do |dir|
        config = described_class.load(dir)

        expect(config.include_globs).to eq(["**/*.html.erb", "**/*.herb"])
        expect(config.exclude_globs).to eq([])
        expect(config.fail_level).to eq(:error)
        expect(config.linter_version).to be_nil
      end
    end

    it "returns documented defaults for keys omitted from a present .herb.yml" do
      with_herb_yml("version: \"0.10.3\"\n") do |dir|
        config = described_class.load(dir)

        expect(config.include_globs).to eq(["**/*.html.erb", "**/*.herb"])
        expect(config.exclude_globs).to eq([])
        expect(config.fail_level).to eq(:error)
      end
    end
  end

  describe "#include_globs / #exclude_globs" do
    it "reads files.include and files.exclude" do
      yaml = <<~YAML
        files:
          include: ["app/**/*.herb"]
          exclude: ["app/vendor/**/*"]
      YAML

      with_herb_yml(yaml) do |dir|
        config = described_class.load(dir)

        expect(config.include_globs).to eq(["app/**/*.herb"])
        expect(config.exclude_globs).to eq(["app/vendor/**/*"])
      end
    end
  end

  describe "#fail_level" do
    it "reads linter.fail_level as a Symbol" do
      with_herb_yml("linter:\n  fail_level: warning\n") do |dir|
        config = described_class.load(dir)

        expect(config.fail_level).to eq(:warning)
      end
    end
  end

  describe "#linter_version" do
    it "reads the top-level version key" do
      with_herb_yml("version: \"0.10.3\"\n") do |dir|
        expect(described_class.load(dir).linter_version).to eq("0.10.3")
      end
    end
  end

  describe "#enabled_rule_names" do
    it "excludes only rules explicitly disabled via linter.rules.<name>.enabled: false" do
      yaml = <<~YAML
        linter:
          rules:
            html-no-space-in-tag:
              enabled: false
            html-tag-name-lowercase:
              enabled: true
      YAML

      with_herb_yml(yaml) do |dir|
        config = described_class.load(dir)
        all = %w[html-no-space-in-tag html-tag-name-lowercase html-no-self-closing]

        expect(config.enabled_rule_names(all)).to contain_exactly(
          "html-tag-name-lowercase", "html-no-self-closing"
        )
      end
    end

    it "returns every rule name unmodified when no rules are disabled" do
      with_herb_yml(nil) do |dir|
        config = described_class.load(dir)
        all = %w[a b c]

        expect(config.enabled_rule_names(all)).to eq(all)
      end
    end

    it "silently ignores a disabled rule name absent from all_rule_names" do
      yaml = <<~YAML
        linter:
          rules:
            some-removed-rule:
              enabled: false
      YAML

      with_herb_yml(yaml) do |dir|
        config = described_class.load(dir)
        all = %w[html-no-space-in-tag]

        expect { config.enabled_rule_names(all) }.not_to raise_error
        expect(config.enabled_rule_names(all)).to eq(all)
      end
    end
  end
end
