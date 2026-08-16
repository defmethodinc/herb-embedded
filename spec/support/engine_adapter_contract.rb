# frozen_string_literal: true

RSpec.shared_examples "an engine adapter" do
  describe "#load" do
    it "evaluates JavaScript source without raising" do
      expect { subject.load("var x = 1;") }.not_to raise_error
    end
  end

  describe "#attach" do
    it "exposes a Ruby block as a callable JS function" do
      subject.attach("ruby_add") { |a, b| a + b }
      subject.load("function useAdd(a, b) { return ruby_add(a, b); }")

      expect(subject.call("useAdd", 2, 3)).to eq(5)
    end
  end

  describe "#call" do
    it "invokes a loaded JS function and returns its result" do
      subject.load("function double(x) { return x * 2; }")

      expect(subject.call("double", 21)).to eq(42)
    end
  end

  describe "#dispose" do
    it "releases engine resources without raising" do
      expect { subject.dispose }.not_to raise_error
    end
  end
end
