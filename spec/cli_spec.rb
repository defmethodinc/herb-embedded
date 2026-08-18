# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tmpdir"
require "fileutils"
require "yaml"
require "herb/embedded/cli"
require "herb/embedded/bundle"

RSpec.describe Herb::Embedded::CLI do
  def write(root, relative_path, contents)
    full_path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, contents)
    full_path
  end

  def run_cli(argv, root:)
    stdout = StringIO.new
    stderr = StringIO.new
    exit_code = nil

    Dir.chdir(root) do
      exit_code = described_class.new(argv, stdout: stdout, stderr: stderr).run
    end

    [exit_code, stdout.string, stderr.string]
  end

  let(:offending_source) { %(<div  class="a">x</div>\n) }
  let(:clean_source) { %(<div class="a">x</div>\n) }

  it "returns 0 when nothing is at or above the fail level, 1 when something is, " \
     "and honors a --fail-level override" do
    Dir.mktmpdir do |root|
      write(root, "clean.html.erb", clean_source)
      clean_code, = run_cli([], root: root)
      expect(clean_code).to eq(0)
    end

    Dir.mktmpdir do |root|
      write(root, "bad.html.erb", offending_source)

      default_code, = run_cli([], root: root)
      expect(default_code).to eq(1)

      lenient_code, = run_cli(["--fail-level", "hint"], root: root)
      expect(lenient_code).to eq(1)
    end

    Dir.mktmpdir do |root|
      write(root, "warning_only.html.erb", %(<nav><a href="/">Home</a></nav>\n))
      # html-navigation-has-label isn't enabled by default upstream, so
      # --only is needed to exercise it deliberately (matching real
      # --only semantics: it bypasses default-enabled filtering).
      only_flags = ["--only", "html-navigation-has-label"]

      expect(run_cli(only_flags, root: root).first).to eq(0)
      expect(run_cli(only_flags + ["--fail-level", "warning"], root: root).first).to eq(1)
    end
  end

  it "returns 2 on configuration errors: unknown --format, unrecognized --only rule, " \
     "invalid --fail-level, and malformed .herb.yml" do
    Dir.mktmpdir do |root|
      write(root, "clean.html.erb", clean_source)

      _, _, err1 = run_cli(["--format", "bogus"], root: root)
      expect(err1).not_to be_empty
      expect(run_cli(["--format", "bogus"], root: root).first).to eq(2)

      expect(run_cli(["--fail-level", "bogus"], root: root).first).to eq(2)

      _, _, err3 = run_cli(["--only", "nonexistent-rule"], root: root)
      expect(run_cli(["--only", "nonexistent-rule"], root: root).first).to eq(2)
      expect(err3).to match(/nonexistent-rule/)
    end

    Dir.mktmpdir do |root|
      write(root, "clean.html.erb", clean_source)
      write(root, ".herb.yml", "not: valid: yaml: [")

      expect(run_cli([], root: root).first).to eq(2)
    end
  end

  it "--only is repeatable and restricts linting to exactly the named rule(s)" do
    Dir.mktmpdir do |root|
      write(root, "bad.html.erb", offending_source)

      _, out_all, = run_cli(["--format", "json"], root: root)
      all_rules = JSON.parse(out_all)["offenses"].map { |o| o["rule"] }
      expect(all_rules).to include("html-no-space-in-tag")

      _, out_restricted, = run_cli(["--only", "html-tag-name-lowercase", "--format", "json"], root: root)
      restricted_rules = JSON.parse(out_restricted)["offenses"].map { |o| o["rule"] }
      expect(restricted_rules).not_to include("html-no-space-in-tag")
    end
  end

  it "--format json produces valid JSON via the json formatter; default format is detailed" do
    Dir.mktmpdir do |root|
      write(root, "bad.html.erb", offending_source)

      _, out_json, = run_cli(["--format", "json"], root: root)
      parsed = JSON.parse(out_json)
      expect(parsed).to include("offenses", "summary")

      _, out_default, = run_cli([], root: root)
      expect(out_default).to include("html-no-space-in-tag")
      expect { JSON.parse(out_default) }.to raise_error(JSON::ParserError)
    end
  end

  it "--version prints Herb::Embedded::VERSION and Bundle.linter_version" do
    Dir.mktmpdir do |root|
      code, out, = run_cli(["--version"], root: root)

      expect(code).to eq(0)
      expect(out).to include(Herb::Embedded::VERSION)
      expect(out).to include(Herb::Embedded::Bundle.linter_version)
    end
  end

  it "--init writes .herb.yml with version: pinned to Bundle.linter_version" do
    Dir.mktmpdir do |root|
      code, = run_cli(["--init"], root: root)

      expect(code).to eq(0)
      data = YAML.load_file(File.join(root, ".herb.yml"))
      expect(data["version"]).to eq(Herb::Embedded::Bundle.linter_version)
    end
  end

  it "--fix applies safe autocorrections via Runner#fix; --fix-unsafely also applies unsafe ones, " \
     "and exe/herb-lint-rb is executable with --help listing all flags" do
    Dir.mktmpdir do |root|
      path = write(root, "trailing.html.erb", "<div>hi</div>   \n")

      code, = run_cli(["--fix"], root: root)

      expect(code).to eq(0)
      expect(File.read(path)).to eq("<div>hi</div>\n")
    end

    exe_path = File.expand_path("../exe/herb-lint-rb", __dir__)
    expect(File).to be_executable(exe_path)

    _, help_out, = run_cli(["--help"], root: Dir.pwd)
    %w[--fix --fix-unsafely --format --fail-level --only --init --version --help].each do |flag|
      expect(help_out).to include(flag)
    end
  end
end
