# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/bundle"
require "herb/embedded/adapters/mini_racer"

RSpec.describe Herb::Embedded::Bundle do
  describe ".source" do
    it "returns the vendored bundle as a non-empty String" do
      expect(described_class.source).to be_a(String)
      expect(described_class.source.bytesize).to be > 1_000_000
    end

    it "contains no reference to a Node built-in module" do
      node_builtin_reference = %r{require\(\s*["']node:[a-z/]+["']\s*\)|require\(\s*["'](fs|path|url|os|crypto|child_process|module|stream|util)["']\s*\)}

      expect(described_class.source).not_to match(node_builtin_reference)
    end

    it "evaluates cleanly in a bare V8 context and exposes the Linter and rules" do
      adapter = Herb::Embedded::Adapters::MiniRacer.new
      adapter.load(File.read(File.expand_path("../js/host_shim.js", __dir__)))
      adapter.load(described_class.source)
      adapter.load(<<~JS)
        function linterType() { return typeof HerbLinter.Linter; }
        function ruleCount() { return Object.keys(HerbLinter.rules).length; }
      JS

      expect(adapter.call("linterType")).to eq("function")
      expect(adapter.call("ruleCount")).to be > 0
    ensure
      adapter&.dispose
    end
  end

  describe ".linter_version" do
    it 'is "0.10.3"' do
      expect(described_class.linter_version).to eq("0.10.3")
    end
  end

  describe ".herb_versions" do
    it 'is ["0.10.3"]' do
      expect(described_class.herb_versions).to eq(["0.10.3"])
    end
  end
end
