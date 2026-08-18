# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/result_envelope"

RSpec.describe Herb::Embedded::ResultEnvelope do
  describe "::FORWARDABLE_OPTIONS" do
    it "matches the documented allowlist derived from Herb::ParserOptions" do
      expect(described_class::FORWARDABLE_OPTIONS).to eq(%i[
                                                           strict
                                                           track_whitespace
                                                           analyze
                                                           action_view_helpers
                                                           transform_conditionals
                                                           render_nodes
                                                           strict_locals
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

    it "never forwards prism_nodes to Herb.parse itself, even when present in options_hash" do
      json = described_class.parse("<%= 1 + 1 %>", prism_nodes: true)

      expect { JSON.parse(json) }.not_to raise_error
    end

    it "injects a JSON-safe prism_node byte array on ERB nodes when prism_nodes is requested" do
      json = described_class.parse("<%= 1 + 1 %>", prism_nodes: true)
      erb_node = JSON.parse(json)["value"]["children"].find { |c| c["type"] == "AST_ERB_CONTENT_NODE" }

      expect(erb_node["prism_node"]).to be_an(Array)
      expect(erb_node["prism_node"]).not_to be_empty
      expect(erb_node["prism_node"]).to all(be_an(Integer))
    end

    it "also injects prism_node byte arrays when prism_nodes_deep is requested" do
      json = described_class.parse("<%= 1 + 1 %>", prism_nodes_deep: true)
      erb_node = JSON.parse(json)["value"]["children"].find { |c| c["type"] == "AST_ERB_CONTENT_NODE" }

      expect(erb_node["prism_node"]).to be_an(Array)
    end

    it "leaves prism_node nil on ERB nodes when neither prism_nodes flag is requested" do
      json = described_class.parse("<%= 1 + 1 %>", {})
      erb_node = JSON.parse(json)["value"]["children"].find { |c| c["type"] == "AST_ERB_CONTENT_NODE" }

      expect(erb_node["prism_node"]).to be_nil
    end

    it "injects a JSON-safe prism_node byte array on the root value when prism_program is requested" do
      json = described_class.parse("<div><%= @foo %></div>\n", prism_program: true)
      envelope = JSON.parse(json)

      expect(envelope["value"]["prism_node"]).to be_an(Array)
      expect(envelope["value"]["prism_node"]).not_to be_empty
      expect(envelope["value"]["prism_node"]).to all(be_an(Integer))
    end

    it "leaves prism_node nil on the root value when prism_program is not requested" do
      json = described_class.parse("<div><%= @foo %></div>\n", {})
      envelope = JSON.parse(json)

      expect(envelope["value"]["prism_node"]).to be_nil
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
    it "returns the envelope shape LexResult.from() expects" do
      json = described_class.lex("<div>hi</div>")
      envelope = JSON.parse(json)

      expect(envelope.keys).to contain_exactly("tokens", "source", "warnings", "errors")
      expect(envelope["tokens"]).not_to be_empty
      expect(envelope["source"]).to eq("<div>hi</div>")
    end
  end
end
