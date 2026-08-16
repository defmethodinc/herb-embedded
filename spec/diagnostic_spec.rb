# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/diagnostic"

RSpec.describe Herb::Embedded::Diagnostic do
  let(:location) { { "start" => { "line" => 3, "column" => 7 }, "end" => { "line" => 3, "column" => 12 } } }

  describe ".from_js" do
    it "maps a JS offense hash into a Diagnostic exposing file, rule, message, severity, line, column, correctable?" do
      offense = {
        "rule" => "html-no-space-in-tag",
        "message" => "Remove extra whitespace.",
        "severity" => "warning",
        "location" => location,
        "autofixContext" => { "node" => {} },
      }

      diagnostic = described_class.from_js(offense, file: "app/views/index.html.erb")

      expect(diagnostic.file).to eq("app/views/index.html.erb")
      expect(diagnostic.rule).to eq("html-no-space-in-tag")
      expect(diagnostic.message).to eq("Remove extra whitespace.")
      expect(diagnostic.severity).to eq(:warning)
      expect(diagnostic.line).to eq(3)
      expect(diagnostic.column).to eq(7)
      expect(diagnostic.correctable?).to be(true)
    end

    it "is not correctable when the offense has no autofixContext" do
      offense = { "rule" => "x", "message" => "y", "severity" => "error", "location" => location }

      diagnostic = described_class.from_js(offense, file: "f.erb")

      expect(diagnostic.correctable?).to be(false)
    end

    it "defaults severity to :error when missing from the offense hash" do
      offense = { "rule" => "x", "message" => "y", "location" => location }

      diagnostic = described_class.from_js(offense, file: "f.erb")

      expect(diagnostic.severity).to eq(:error)
    end

    it "defaults severity to :error when the offense hash has an unrecognized severity" do
      offense = { "rule" => "x", "message" => "y", "severity" => "catastrophic", "location" => location }

      diagnostic = described_class.from_js(offense, file: "f.erb")

      expect(diagnostic.severity).to eq(:error)
    end
  end

  describe "#to_h" do
    it "returns a Hash with a fixed key set matching upstream Herb::Diagnostic#to_h (marcoroth/herb#455)" do
      offense = { "rule" => "x", "message" => "y", "severity" => "info", "location" => location }

      diagnostic = described_class.from_js(offense, file: "f.erb")

      expect(diagnostic.to_h.keys).to contain_exactly(:message, :location, :severity, :code, :source, :rule)
    end
  end
end
