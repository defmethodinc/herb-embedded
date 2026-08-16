# Project Instructions for AI Agents

Read `CHARTER.md` before doing any work. It defines what this gem is,
what "good" means here, and what is explicitly out of scope.

If a task appears to conflict with the charter, or requires settling one
of its open questions, stop and say so. Do not resolve it yourself.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker
This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.
### Quick Reference
```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```
### Rules
- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files
**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.
## Agent Context Profiles
The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.
- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.
## Session Completion
This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.
1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status
   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step
**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

## Overrides

These take precedence over the Beads integration block above.

- **Never run `bd close`.** Beads close after a PR merges, not when it
  opens. `/land` handles closing.
- **`/ship` may commit, push, and open a PR.** That is explicit authority
  from the command; the conservative profile does not apply to it.
- **Never stash, and never switch branches.** If the working tree contains
  changes unrelated to the current bead, stop and report.

## Build & Test

```bash
bundle install
bundle exec rake      # the full local gate: tests + lint
```

## Architecture Overview

_See CHARTER.md for what this gem is and why — this section is for how it's
built. For rationale behind a specific decision below, check CHARTER.md's
Shape decisions first rather than assuming it's undocumented._

### Module layout

**Engine boundary**
- `EngineAdapter` — the port. Four methods (`load`, `attach`, `call`,
  `dispose`) plus `.binary`. What a new JS engine must implement.
- `Adapters::MiniRacer` — reference implementation (V8 via mini_racer).
- `Bundle` — the vendored JS artifact plus validated-version metadata
  (`source`, `linter_version`, `herb_versions`).

**Bridge / parsing**
- `Bridge` — owns engine lifecycle: boots the host shim, the bundle, and
  `RubyBackend`; attaches the Ruby callbacks; gates boot on
  `Bundle.herb_versions`. `#lint`/`#autofix` are the per-file entry points
  once built.
- `ResultEnvelope` — builds the `{value, source, warnings, errors, options}`
  wire envelope that `Herb.parse`/`Herb.lex` don't produce natively
  (`Herb::ParseResult#to_json` is an inspect string, not the wire format).
- `js/host_shim.js` — TextDecoder/TextEncoder for bare V8.
- `js/ruby_backend.js` — the only JS this project authors: `RubyBackend`
  subclasses `HerbBackend`, delegating each method to a `rbXxx` Ruby
  callback `Bridge` attaches.

**Result shape**
- `Diagnostic`, `LintResult`, `Report` — value objects and an aggregator,
  field-compatible with upstream `Herb::Diagnostic`/`Herb::LintResult`
  (marcoroth/herb#455).

**Orchestration**
- `Config` — reads `.herb.yml`.
- `CustomRuleLoader` — globs `.herb/rules/*.mjs`, rewrites the one
  supported import (`@herb-tools/linter`) into a bundle-global destructure,
  registers the result alongside built-in rules.
- `Runner` — file discovery (`Dir.glob`) plus orchestration:
  `Runner.new(config:, bridge:).run(paths) #=> Report`.
- `Formatters::{Detailed, Simple, JSON, GitHub}` — `#render(report) #=> String`.

**CLI**
- `exe/herb-lint-rb` — flag parsing (`--fix`, `--format`, `--only`, etc.),
  wires `Config` → `Bridge` → `Runner` → a `Formatter`, sets the exit code.

### The parser boundary

Two shapes cross the Ruby/JS boundary, for two different reasons:

- **AST as JSON.** `ResultEnvelope.parse`/`.lex` serialize `Herb.parse`/
  `Herb.lex` (native C ext) output to JSON; `RubyBackend#parse`/`#lex` just
  `JSON.parse` it back on the JS side. The two sides already agree on node
  type names (`AST_*`) with no translation layer needed.
- **Prism as binary.** The 15 Prism-dependent rules need live, walkable
  `PrismNode` objects, not JSON, so `rbParseRuby` returns `Prism.dump`'s
  self-describing versioned binary format, wrapped as `MiniRacer::Binary` so
  the adapter marshals it as a `Uint8Array`.

`Bridge` currently attaches **six** callbacks — `rbParse`, `rbLex`,
`rbExtractRuby`, `rbExtractHTML`, `rbParseRuby`, `rbVersion` — one per
`HerbBackend` method the bundle calls, not just the two (`parse`/`parseRuby`)
that matter for rule execution. The other three exist because `HerbBackend`'s
interface requires them, not because more rules depend on them.

### Extension points

- **A new JS engine** implements `EngineAdapter`'s four methods and must pass
  the shared conformance suite in `spec/support/engine_adapter_contract.rb`
  — including carrying `EngineAdapter::Binary` values, which the
  Prism-dependent rules require. See CHARTER.md.
- **Custom rules** (`.herb/rules/*.mjs`) load through `CustomRuleLoader`,
  which supports exactly one import specifier (`@herb-tools/linter`)
  rewritten at load time. Anything else fails loudly by design rather than
  producing a runtime `ReferenceError` — see CHARTER.md's Out of scope.

## Conventions & Patterns

### Naming

- `Herb::Embedded` namespace. Classes/modules PascalCase, methods snake_case.
- Predicate methods end in `?` (`correctable?`), never `is_`/`has_` prefixes.
- Constants are `SCREAMING_SNAKE_CASE` and `.freeze`d when they're arrays/hashes
  (`SEVERITIES`, `FORWARDABLE_OPTIONS`).
- A class method that builds an instance from data crossing the JS boundary is named
  `.from_js` (see `Diagnostic.from_js`). Use that name for any future value object built
  the same way, rather than inventing a new verb per class.

### Error handling

- All errors this gem raises inherit from `Herb::Embedded::Error < StandardError`, so a
  consumer can `rescue Herb::Embedded::Error` to mean "this gem said no" without also
  catching unrelated bugs. Add specific subclasses as real failure modes show up (e.g. an
  adapter-unavailable error, a version-mismatch error) rather than raising the base class
  directly.
- Failure messages should be actionable, not backtraces — this matters most at process
  boundaries (CLI, adapter boot). See the design spec's failure-modes table in
  `CHARTER.md`/the linked design doc for the specific cases this governs (missing engine
  gem, unvalidated `herb` version, a rule throwing inside JS, etc).

### Mutability

Value objects (`Diagnostic`, `LintResult`, future ones like `Config`): keyword-arg
initializer, `attr_reader`, no setters. Aggregators (`Report`) are the one exception and may
mutate via an explicit method like `#add` — see CHARTER.md's Shape decisions for why. Stateless
logic with no meaningful instance state (`Bundle`, `ResultEnvelope`) is a `module_function`
module, not a class.

### Test structure

- RSpec. One spec file per lib unit, `spec/<path>_spec.rb` mirroring `lib/<path>.rb`. See
  CHARTER.md's Shape decisions for why RSpec over the original plan's minitest.
- Unit tests for anything that depends on a collaborator (e.g. `Bridge` needing an
  `EngineAdapter`, `Runner` needing a `Bridge`) use a hand-written fake living in
  `spec/support/`, following the existing `spec/support/engine_adapter_contract.rb` pattern
  — not RSpec verified doubles. A fake is a small real class implementing the port; write
  one per collaborator interface and reuse it across specs.
- Conformance/contract suites that every implementation of a port must satisfy (the adapter
  conformance suite, and later anything with the same "multiple implementations, one
  contract" shape) are shared examples in `spec/support/`, run against real implementations
  — never against fakes or doubles, since the point is proving the real thing works.

### Public vs. internal API

Consumer-facing (safe to depend on; changes here are breaking):

- `Runner`, `Config`, `Diagnostic`, `LintResult`, `Report`, `Formatters::*`
- the `herb-lint-rb` executable and its flags

Extension point (public to anyone writing a new engine adapter, irrelevant to everyone
else):

- `EngineAdapter` (the port) and the adapter conformance suite it must pass

Internal plumbing (no stability guarantee, change freely):

- `Bridge`, `ResultEnvelope`, `Bundle`, `CustomRuleLoader`, `Adapters::MiniRacer` (the
  reference adapter's own internals, as opposed to the port it implements)
