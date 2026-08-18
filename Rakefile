# frozen_string_literal: true

require "bundler/gem_tasks"
require "bundler/audit/task"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
Bundler::Audit::Task.new

# bundle:audit only checks against whatever local ruby-advisory-db clone it
# finds (cloning it fresh if missing, but not refreshing an existing one) —
# see guides.rubygems.org/security. CI always refreshes it explicitly
# (bundle:audit:update, see .github/workflows/ci.yml) so that check never
# runs against a stale snapshot there; a local clone only goes stale between
# `bundle exec rake bundle:audit:update` runs, which is an acceptable
# trade-off against forcing network access on every local `rake` invocation.
task default: %i[rubocop spec bundle:audit]
