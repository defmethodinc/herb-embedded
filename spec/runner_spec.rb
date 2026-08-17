# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "herb/embedded/runner"
require "herb/embedded/config"
require "herb/embedded/bridge"
require "herb/embedded/bundle"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::Runner do
  let(:adapter) { Herb::Embedded::Adapters::MiniRacer.new }
  let(:bridge) { Herb::Embedded::Bridge.new(adapter: adapter, bundle: Herb::Embedded::Bundle).boot }

  after { adapter.dispose }

  def write(root, relative_path, contents)
    full_path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, contents)
    full_path
  end

  let(:offending_source) { %(<div  class="a">x</div>\n) }

  it "discovers files via Config#include_globs (excluding Config#exclude_globs), returns a Report, " \
     "with Diagnostic#file relative to root" do
    Dir.mktmpdir do |root|
      write(root, "good.html.erb", offending_source)
      write(root, "excluded/skip.html.erb", offending_source)
      write(root, "other.txt", "not html-erb")

      config = Herb::Embedded::Config.new(
        "files" => { "include" => ["**/*.html.erb"], "exclude" => ["excluded/**/*"] },
      )
      runner = described_class.new(root: root, config: config, bridge: bridge)

      report = runner.run

      expect(report.files_checked).to eq(1)
      expect(report.diagnostics).not_to be_empty
      expect(report.diagnostics.map(&:file)).to eq(["good.html.erb"])
    end
  end

  it "lints only explicitly given paths, ignoring the configured globs" do
    Dir.mktmpdir do |root|
      path = write(root, "explicit.html.erb", offending_source)

      config = Herb::Embedded::Config.new("files" => { "include" => ["nonexistent/**/*"] })
      runner = described_class.new(root: root, config: config, bridge: bridge)

      report = runner.run([path])

      expect(report.files_checked).to eq(1)
      expect(report.diagnostics.map(&:file)).to eq(["explicit.html.erb"])
    end
  end

  it "#fix runs autofix then re-lints, writing corrected content to disk for modified files" do
    Dir.mktmpdir do |root|
      path = write(root, "trailing.html.erb", "<div>hi</div>   \n")

      config = Herb::Embedded::Config.new("files" => { "include" => ["**/*.html.erb"] })
      runner = described_class.new(root: root, config: config, bridge: bridge)

      report = runner.fix

      expect(File.read(path)).to eq("<div>hi</div>\n")
      expect(report.diagnostics.map(&:rule)).not_to include("erb-no-trailing-whitespace")
    end
  end

  it "loads custom rules once per Runner instance, not reloaded on subsequent run/fix calls" do
    Dir.mktmpdir do |root|
      write(root, "clean.html.erb", "<div>hi</div>\n")
      config = Herb::Embedded::Config.new("files" => { "include" => ["**/*.html.erb"] })
      runner = described_class.new(root: root, config: config, bridge: bridge)

      expect(Herb::Embedded::CustomRuleLoader).to receive(:new).once.and_call_original

      runner.run
      runner.run
    end
  end
end
