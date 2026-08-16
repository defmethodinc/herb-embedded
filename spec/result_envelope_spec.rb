# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/result_envelope"

RSpec.describe Herb::Embedded::ResultEnvelope do
  describe "::FORWARDABLE_OPTIONS" do
    it "matches the documented allowlist derived from Herb::ParserOptions" do
      expect(described_class::FORWARDABLE_OPTIONS).to eq(%i[
                                                           strict
                                                           track_whitespace
                                                           track_locations
                                                           analyze
                                                           action_view_helpers
                                                           transform_conditionals
                                                           render_nodes
                                                           strict_locals
                                                           iteration_nodes
                                                         ])
    end
  end

  describe ".parse" do
    it "returns the envelope shape ParseResult.from() expects, including serialized parse errors" do
      json = described_class.parse("<div>", {})
      envelope = JSON.parse(json)

      expect(envelope.keys).to contain_exactly("value", "source", "warnings", "errors", "options")
      expect(envelope["source"]).to eq("<div>")
      expect(envelope["errors"]).not_to be_empty
      expect(envelope["errors"].first).to include("type", "location", "message")
    end

    it "ignores unrecognized option keys instead of raising" do
      expect { described_class.parse("<div></div>", strict: true, bogus_option: "explode") }
        .not_to raise_error
    end

    it "never forwards prism_nodes, even when present in options_hash" do
      json = described_class.parse("<%= 1 + 1 %>", prism_nodes: true)

      expect { JSON.parse(json) }.not_to raise_error
    end

    it "forwards track_whitespace and observably changes parse output" do
      source = %(<div  class="a">x</div>)

      default_json = described_class.parse(source, {})
      tracked_json = described_class.parse(source, track_whitespace: true)

      expect(default_json).not_to include("WHITESPACE")
      expect(tracked_json).to include("WHITESPACE")
    end
  end

  describe ".lex" do
    it "returns the equivalent envelope shape for Herb.lex" do
      json = described_class.lex("<div>hi</div>")
      envelope = JSON.parse(json)

      expect(envelope.keys).to contain_exactly("value", "source", "warnings", "errors")
      expect(envelope["value"]).not_to be_empty
      expect(envelope["source"]).to eq("<div>hi</div>")
    end
  end
end
