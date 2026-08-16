# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/adapters/mini_racer"

RSpec.describe "js/host_shim.js" do
  let(:shim_source) { File.read(File.expand_path("../js/host_shim.js", __dir__)) }
  let(:adapter) { Herb::Embedded::Adapters::MiniRacer.new }

  after { adapter.dispose }

  def load_shim_with_helpers(helpers)
    adapter.load(shim_source)
    adapter.load(helpers)
  end

  it "leaves TextDecoder undefined in a fresh V8 context before the shim loads" do
    adapter.load("function checkTextDecoder() { return typeof TextDecoder; }")

    expect(adapter.call("checkTextDecoder")).to eq("undefined")
  end

  it "decodes valid multi-byte UTF-8 input into the equivalent JS string" do
    load_shim_with_helpers(<<~JS)
      function decodeBytes(byteArray) {
        return new TextDecoder().decode(new Uint8Array(byteArray));
      }
    JS

    str = "héllo wörld 日本語"

    expect(adapter.call("decodeBytes", str.bytes)).to eq(str)
  end

  it "round-trips decode(encode(str)) for a multi-byte string" do
    load_shim_with_helpers(<<~JS)
      function roundTrip(str) {
        return new TextDecoder().decode(new TextEncoder().encode(str));
      }
    JS

    str = "héllo wörld 日本語"

    expect(adapter.call("roundTrip", str)).to eq(str)
  end

  it "encodes to the string's UTF-8 byte length, not its JS .length" do
    load_shim_with_helpers(<<~JS)
      function encodedLength(str) {
        return new TextEncoder().encode(str).length;
      }
    JS

    str = "日本語"

    expect(adapter.call("encodedLength", str)).to eq(str.bytesize)
    expect(str.bytesize).not_to eq(str.length)
  end

  it "throws when decode is given a plain string instead of bytes" do
    load_shim_with_helpers(<<~JS)
      function decodeString(str) {
        return new TextDecoder().decode(str);
      }
    JS

    expect { adapter.call("decodeString", "not bytes") }
      .to raise_error(MiniRacer::RuntimeError, /TypeError/)
  end
end
