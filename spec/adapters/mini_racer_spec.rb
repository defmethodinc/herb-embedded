# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::Adapters::MiniRacer do
  subject { described_class.new }

  include_examples "an engine adapter"

  describe ".binary" do
    it "round-trips arbitrary bytes through #call without corruption" do
      subject.load("function identity(x) { return x; }")
      original = (0..255).to_a.pack("C*")

      result = subject.call("identity", Herb::Embedded::EngineAdapter.binary(original))

      expect(result.pack("C*")).to eq(original)
    end

    it "marshals a Binary returned from an attached callback into a JS Uint8Array" do
      original = (0..255).to_a.pack("C*")
      subject.attach("getBinary") { Herb::Embedded::EngineAdapter.binary(original) }
      subject.load(<<~JS)
        function describeBinary() {
          var b = getBinary();
          return b.constructor.name + " " + b.length;
        }
      JS

      expect(subject.call("describeBinary")).to eq("Uint8Array 256")
    end
  end
end
