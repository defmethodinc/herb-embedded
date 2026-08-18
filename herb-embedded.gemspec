# frozen_string_literal: true

require_relative "lib/herb/embedded/version"

Gem::Specification.new do |spec|
  spec.name = "herb-embedded"
  spec.version = Herb::Embedded::VERSION
  spec.authors = ["Herb Embedded contributors"]
  spec.summary = "Embedded Herb linter for Ruby via a pluggable JavaScript engine adapter"
  spec.required_ruby_version = ">= 3.2"

  # An explicit git-tracked allowlist, not Dir[] globs: a pushed gem is
  # public and widely mirrored, so a stray file that happens to match a
  # broad glob (a local debug script, an untracked scratch file) would
  # ship with no review catching it before `gem push` — and a published
  # version can only be yanked, not recalled from whoever already has it.
  # See guides.rubygems.org/security.
  spec.files = `git ls-files -z`.split("\x0").select do |file|
    file.match?(%r{\Alib/.*\.rb\z}) ||
      file.match?(%r{\Avendor/.*\.js\z}) ||
      file.match?(%r{\Ajs/.*\.js\z}) ||
      file.match?(%r{\Aexe/[^/]+\z})
  end
  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  spec.executables = ["herb-lint-rb"]

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
