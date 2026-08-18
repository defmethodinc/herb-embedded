# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::Adapters::MiniRacer do
  subject(:adapter) { described_class.new }

  it_behaves_like "an engine adapter"

  describe ".binary" do
    it "round-trips arbitrary bytes through #call without corruption" do
      adapter.load("function identity(x) { return x; }")
      original = (0..255).to_a.pack("C*")

      result = adapter.call("identity", Herb::Embedded::EngineAdapter.binary(original))

      expect(result.pack("C*")).to eq(original)
    end

    it "marshals a Binary returned from an attached callback into a JS Uint8Array" do
      original = (0..255).to_a.pack("C*")
      adapter.attach("getBinary") { Herb::Embedded::EngineAdapter.binary(original) }
      adapter.load(<<~JS)
        function describeBinary() {
          var b = getBinary();
          return b.constructor.name + " " + b.length;
        }
      JS

      expect(adapter.call("describeBinary")).to eq("Uint8Array 256")
    end
  end
end
