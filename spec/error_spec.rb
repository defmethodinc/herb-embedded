# frozen_string_literal: true

require "spec_helper"
require "herb/embedded/bridge"

RSpec.describe Herb::Embedded::Error do
  it "is a StandardError subclass" do
    expect(described_class.ancestors).to include(StandardError)
  end

  it "is the common ancestor for Bridge's error classes" do
    expect(Herb::Embedded::Bridge::VersionMismatchError.ancestors).to include(described_class)
    expect(Herb::Embedded::Bridge::NotBootedError.ancestors).to include(described_class)
    expect(Herb::Embedded::Bridge::BootError.ancestors).to include(described_class)
  end
end
