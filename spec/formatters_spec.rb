# frozen_string_literal: true

require "spec_helper"
require "json"
require "herb/embedded/formatters"
require "herb/embedded/diagnostic"
require "herb/embedded/lint_result"
require "herb/embedded/report"

RSpec.describe Herb::Embedded::Formatters do
  def diagnostic(file:, rule:, severity: "error", correctable: false)
    offense = {
      "rule" => rule,
      "message" => "Offense from #{rule}",
      "severity" => severity,
      "location" => { "start" => { "line" => 3, "column" => 7 }, "end" => { "line" => 3, "column" => 12 } },
    }
    offense["autofixContext"] = { "node" => {} } if correctable

    Herb::Embedded::Diagnostic.from_js(offense, file: file)
  end

  let(:report) do
    Herb::Embedded::Report.new.tap do |r|
      r.add(Herb::Embedded::LintResult.new(
              file: "a.html.erb",
              diagnostics: [diagnostic(file: "a.html.erb", rule: "html-no-space-in-tag", correctable: true)],
            ))
      r.add(Herb::Embedded::LintResult.new(
              file: "b.html.erb",
              diagnostics: [diagnostic(file: "b.html.erb", rule: "erb-no-debug-output", severity: "warning")],
            ))
    end
  end

  describe ".fetch(:simple)" do
    it "renders one file:line:col severity message (rule) line per offense, plus a summary" do
      output = described_class.fetch(:simple).render(report)
      lines = output.lines.map(&:chomp)

      expect(lines).to include("a.html.erb:3:7 error Offense from html-no-space-in-tag (html-no-space-in-tag)")
      expect(lines).to include("b.html.erb:3:7 warning Offense from erb-no-debug-output (erb-no-debug-output)")
      expect(lines.last).to include("2 offenses")
    end
  end

  describe ".fetch(:detailed)" do
    it "groups output by file and flags correctable offenses" do
      output = described_class.fetch(:detailed).render(report)

      a_index = output.index("a.html.erb")
      b_index = output.index("b.html.erb")
      rule_a_index = output.index("html-no-space-in-tag")
      rule_b_index = output.index("erb-no-debug-output")

      expect(a_index).to be < rule_a_index
      expect(rule_a_index).to be < b_index
      expect(b_index).to be < rule_b_index
      expect(output).to match(/html-no-space-in-tag.*correctable/i)
      expect(output).not_to match(/erb-no-debug-output.*correctable/i)
    end
  end

  describe ".fetch(:json)" do
    it "outputs valid JSON with offenses and a files_checked/offenses/correctable summary" do
      parsed = JSON.parse(described_class.fetch(:json).render(report))

      expect(parsed["offenses"].size).to eq(2)
      expect(parsed["summary"]).to eq({ "files_checked" => 2, "offenses" => 2, "correctable" => 1 })
    end
  end

  describe ".fetch(:github)" do
    it "outputs one GitHub Actions ::error annotation line per offense" do
      output = described_class.fetch(:github).render(report)
      lines = output.lines.map(&:chomp)

      expect(lines).to include("::error file=a.html.erb,line=3,col=7::Offense from html-no-space-in-tag")
      expect(lines).to include("::error file=b.html.erb,line=3,col=7::Offense from erb-no-debug-output")
    end
  end

  describe ".fetch with an unknown formatter name" do
    it "raises" do
      expect { described_class.fetch(:nonexistent) }.to raise_error(ArgumentError, /nonexistent/)
    end
  end
end
