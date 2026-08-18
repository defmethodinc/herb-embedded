# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/diagnostic"
require "herb/embedded/lint_result"

RSpec.describe Herb::Embedded::LintResult do
  it "exposes #file and #diagnostics" do
    diagnostic = Herb::Embedded::Diagnostic.from_js(
      { "rule" => "x", "message" => "y", "severity" => "error", "location" => {} }, file: "a.erb"
    )

    result = described_class.new(file: "a.erb", diagnostics: [diagnostic])

    expect(result.file).to eq("a.erb")
    expect(result.diagnostics).to eq([diagnostic])
  end
end
