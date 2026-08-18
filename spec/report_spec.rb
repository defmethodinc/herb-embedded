# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/diagnostic"
require "herb/embedded/lint_result"
require "herb/embedded/report"

RSpec.describe Herb::Embedded::Report do
  def diagnostic(severity:, correctable: false, autofix: false)
    offense = { "rule" => "x", "message" => "y", "severity" => severity, "location" => {} }
    offense["autofixContext"] = { "node" => {} } if correctable || autofix

    Herb::Embedded::Diagnostic.from_js(offense, file: "irrelevant")
  end

  describe "#add / #diagnostics / #files_checked / #files_with_offenses / #correctable_count" do
    it "accumulates results and aggregates across them" do
      report = described_class.new

      clean = Herb::Embedded::LintResult.new(file: "clean.erb", diagnostics: [])
      dirty = Herb::Embedded::LintResult.new(
        file: "dirty.erb",
        diagnostics: [diagnostic(severity: "error", correctable: true), diagnostic(severity: "warning")],
      )

      report.add(clean)
      report.add(dirty)

      expect(report.diagnostics).to eq(dirty.diagnostics)
      expect(report.files_checked).to eq(2)
      expect(report.files_with_offenses).to eq(1)
      expect(report.correctable_count).to eq(1)
    end

    it "returns zero counts for an empty report" do
      report = described_class.new

      expect(report.diagnostics).to eq([])
      expect(report.files_checked).to eq(0)
      expect(report.files_with_offenses).to eq(0)
      expect(report.correctable_count).to eq(0)
    end
  end

  describe "#exit_code" do
    it "is nonzero when a diagnostic meets or exceeds fail_level" do
      report = described_class.new
      report.add(Herb::Embedded::LintResult.new(file: "a.erb", diagnostics: [diagnostic(severity: "error")]))

      expect(report.exit_code(fail_level: :warning)).not_to eq(0)
    end

    it "is zero when no diagnostic reaches fail_level" do
      report = described_class.new
      report.add(Herb::Embedded::LintResult.new(file: "a.erb", diagnostics: [diagnostic(severity: "info")]))

      expect(report.exit_code(fail_level: :error)).to eq(0)
    end

    it "is zero for an empty report" do
      report = described_class.new

      expect(report.exit_code(fail_level: :hint)).to eq(0)
    end

    it "ranks severities error > warning > info > hint" do
      report = described_class.new
      report.add(Herb::Embedded::LintResult.new(file: "a.erb", diagnostics: [diagnostic(severity: "warning")]))

      expect(report.exit_code(fail_level: :error)).to eq(0)
      expect(report.exit_code(fail_level: :warning)).not_to eq(0)
      expect(report.exit_code(fail_level: :info)).not_to eq(0)
      expect(report.exit_code(fail_level: :hint)).not_to eq(0)
    end
  end
end
