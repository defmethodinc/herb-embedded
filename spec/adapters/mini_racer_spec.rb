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
  end
end
