# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/bridge"
require "herb/embedded/bundle"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::Bridge do
  let(:bundle) { Herb::Embedded::Bundle }
  let(:adapter) { Herb::Embedded::Adapters::MiniRacer.new }

  after { adapter.dispose }

  it "boots successfully, wires all six callbacks, and reports a version sourced from the bundle" do
    bridge = described_class.new(adapter: adapter, bundle: bundle)

    bridge.boot

    expect(bridge.backend_version).to include(bundle.linter_version)

    parse_envelope = JSON.parse(adapter.call("rbParse", "<div>hi</div>", {}))
    expect(parse_envelope.keys).to contain_exactly("value", "source", "warnings", "errors", "options")

    lex_envelope = JSON.parse(adapter.call("rbLex", "<div>hi</div>"))
    expect(lex_envelope["tokens"]).not_to be_empty

    expect(adapter.call("rbExtractRuby", "<%= 1 %>", {})).to be_a(String)
    expect(adapter.call("rbExtractHTML", "<div>hi</div>")).to be_a(String)
    expect(adapter.call("rbVersion")).to include("herb gem")
  end

  describe "version gating" do
    it "raises VersionMismatchError iff Herb::VERSION is absent from Bundle.herb_versions" do
      valid_bundle = Struct.new(:source, :linter_version, :herb_versions).new(
        bundle.source, bundle.linter_version, [Herb::VERSION]
      )
      invalid_bundle = Struct.new(:source, :linter_version, :herb_versions).new(
        bundle.source, bundle.linter_version, ["0.0.1"]
      )

      expect { described_class.new(adapter: adapter, bundle: valid_bundle).boot }.not_to raise_error

      other_adapter = Herb::Embedded::Adapters::MiniRacer.new
      expect { described_class.new(adapter: other_adapter, bundle: invalid_bundle).boot }
        .to raise_error(described_class::VersionMismatchError)
      other_adapter.dispose
    end
  end

  it "round-trips Prism.dump into a walkable PrismNode graph in JS" do
    bridge = described_class.new(adapter: adapter, bundle: bundle)
    bridge.boot

    adapter.load(<<~JS)
      function prismNodeType(source) {
        var bytes = rbParseRuby(source);
        var result = HerbLinter.deserializePrismParseResult(bytes, source);
        return result.value.constructor.name;
      }
    JS

    expect(adapter.call("prismNodeType", "1 + 1")).to eq("ProgramNode")
  end

  it "raises NotBootedError before #boot, and #dispose releases the adapter" do
    own_adapter = Herb::Embedded::Adapters::MiniRacer.new
    bridge = described_class.new(adapter: own_adapter, bundle: bundle)

    expect { bridge.backend_version }.to raise_error(described_class::NotBootedError)

    bridge.dispose

    expect { own_adapter.load("1") }.to raise_error(MiniRacer::ContextDisposedError)
  end
end
