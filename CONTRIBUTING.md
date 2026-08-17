# Contributing to herb-embedded

Thanks for your interest in contributing.

## Development setup

```bash
bundle install
```

Node is **not** required to run the gem or its test suite — only `rake bundle:build` (regenerating the
vendored `@herb-tools/linter` bundle) needs it, and that's a maintainer/CI task, not something you need
for day-to-day development.

## Running the specs

```bash
bundle exec rspec
```

## Running RuboCop

```bash
bundle exec rubocop
```

Both are also available together via `bundle exec rake`, which is what CI runs.

## The no-Node guarantee

herb-embedded's entire reason for existing is running Herb's real lint rules in a pure Ruby process, with
no Node.js required at runtime. Node is a build-time tool for producing the vendored JS bundle — the same
relationship `tailwindcss-ruby` has with the Tailwind toolchain.

Any runtime code path that shells out, spawns a process, or touches `node_modules` is a defect. PRs that
break this guarantee will not merge, regardless of what else they accomplish.

## Pull requests

* `main` is the merge base for all PRs.
* Any behavior change needs a spec. If your change touches a code path that could affect the no-Node
  guarantee, describe how you verified it doesn't.
* Add a CHANGELOG entry under `## unreleased` in `CHANGELOG.md`.
* Draft PRs are welcome for early feedback — you don't need a finished change to open one.
