# frozen_string_literal: true

require_relative "lib/herb/embedded/version"

Gem::Specification.new do |spec|
  spec.name = "herb-embedded"
  spec.version = Herb::Embedded::VERSION
  spec.authors = ["Herb Embedded contributors"]
  spec.summary = "Embedded Herb linter for Ruby via a pluggable JavaScript engine adapter"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb"] + Dir["vendor/**/*.js"] + Dir["js/**/*.js"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/defmethodinc/herb-embedded/issues",
    "changelog_uri" => "https://github.com/defmethodinc/herb-embedded/blob/main/CHANGELOG.md",
    "source_code_uri" => "https://github.com/defmethodinc/herb-embedded",
    "homepage_uri" => "https://github.com/defmethodinc/herb-embedded",
    "rubygems_mfa_required" => "true",
  }

  spec.add_dependency "herb", "~> 0.10.3"
  spec.add_dependency "mini_racer", "~> 0.22"
end
