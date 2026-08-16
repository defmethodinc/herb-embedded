# frozen_string_literal: true

require_relative "lib/herb/embedded/version"

Gem::Specification.new do |spec|
  spec.name = "herb-embedded"
  spec.version = Herb::Embedded::VERSION
  spec.authors = ["Herb Embedded contributors"]
  spec.summary = "Embedded Herb linter for Ruby via a pluggable JavaScript engine adapter"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "mini_racer", "~> 0.22"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
end
