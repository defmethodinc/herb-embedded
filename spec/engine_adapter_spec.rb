# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::EngineAdapter do
  describe "abstract interface" do
    subject(:adapter) { described_class.new }

    it "raises NotImplementedError for #load" do
      expect { adapter.load("1") }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #attach" do
      expect { adapter.attach("x") { 1 } }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #call" do
      expect { adapter.call("fn") }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #dispose" do
      expect { adapter.dispose }.to raise_error(NotImplementedError)
    end
  end

  describe "contract compliance" do
    subject { Herb::Embedded::Adapters::MiniRacer.new }

    include_examples "an engine adapter"
  end
end
