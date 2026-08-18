# Handoff — 2026-08-18

## What got worked on, and current state

Three beads shipped and merged this session, in dependency order, plus v0.10.3.0
got released to RubyGems by the end of it:

1. **herb-embedded-gu7** (PR #44, merged) — Wired `prism_program` injection.
   `ResultEnvelope.parse` now computes `Prism.dump(Herb.extract_ruby(source)).bytes`
   (a JSON-safe `Integer` array, never the raw ASCII-8BIT string that broke
   `.to_json` before) and injects it onto the root parsed value's `prism_node`
   key when a rule's `parserOptions` ask for `prism_program`. Covers 2 of 12
   prism-dependent rules (`erb-no-debug-output`,
   `erb-no-instance-variables-in-partials`).

2. **herb-embedded-ada** (PR #47, merged) — Wired `prism_nodes`/`prism_nodes_deep`
   for the other 10 prism-dependent rules. Harder problem: each `AST_ERB_*` node
   needs its *own* scoped Prism parse (not one whole-document parse), but still
   offset-correct against the whole file. Solution: for each node, blank every
   byte *outside* its own `content.range` (preserving newlines) and re-dump —
   same blanking trick as `extract_ruby`, just scoped per-node instead of
   per-document. Ruby's `Prism.dump` has no API to serialize an arbitrary
   sub-node (always roots at `ProgramNode`), but every consuming rule expects
   `prismNode` to be the inner expression directly — fixed with a one-time
   getter patch in `js/ruby_backend.js` (ours, not the vendored bundle) that
   unwraps a single-statement `ProgramNode` down to `statements.body[0]`.

3. **herb-embedded-ag7** (PR #48, merged) — Expanded conformance fixtures from
   5 to 100 (one per registered rule, `bridge.rule_names.size == 100` — this is
   the correct, verified count; the npm package's `src/rules/` shows 106 files
   but 6 are shared utility modules, not rules). Authored via 6 parallel
   subagents (batched by rule prefix), each validating against the real
   `node_modules/.bin/herb-lint --only <rule>` CLI before reporting done.
   Extended (not duplicated) the existing `reference_offenses`/`bridge_offenses`
   helpers with `only:`/`rules:` kwargs. Added a coverage-gate test so a future
   upstream rule with no fixture fails the build. **This surfaced a real,
   previously-undetected bridge bug**: `__herbLint`/`__herbAutofix` construct
   `HerbLinter.Linter` without its 4th constructor arg (`allAvailableRules`),
   which silently defaults to just the one selected rule. `herb-disable-comment-unnecessary`
   depends on that arg to recognize *other* rule names referenced in a
   `herb:disable` comment — under our one-rule-at-a-time execution model it
   could never recognize anything but itself. Fixed by passing `HerbLinter.rules`
   explicitly at both call sites.

4. **Release prep + v0.10.3.0 published.** User built the gem locally, smoke-tested
   it in a real Rails app (`bundle exec herb-lint-rb` found a real offense in
   `mailer.html.erb`, `--fix` cleaned it correctly), then fixed up CHANGELOG.md
   (had gotten a duplicate/misplaced header — `## v0.10.3.0 / <date>` landed
   under `## unreleased` instead of replacing `TBD` on the real entry) and
   README.md (install instructions updated from "not yet published, use git:"
   to the standard `gem "herb-embedded"` / `gem install herb-embedded` form).
   PR #49 merged to main, then `bundle exec rake release` run from main
   (correct order — tag needs to land on main's history, not a feature branch).
   Confirmed: **tag `v0.10.3.0` exists on origin, pointing at the main merge
   commit** — the release almost certainly completed successfully end to end,
   including the `gem push` step (not independently reconfirmed against
   RubyGems.org's index over network, but nothing in the visible history
   suggests it stalled).

Working tree is clean on `main`, fully synced with origin. All three beads
closed in `bd`. Local branches `herb-embedded-gu7`, `herb-embedded-xbi`,
`herb-embedded-yi8`, `release_0.10.3.0` are stale (already merged) and could
be pruned with `git branch -d` — left alone since cleanup wasn't asked for.

## What I learned that isn't obvious from the code or the beads

- **This working directory is shared with at least one other concurrent
  session.** Mid-session, the checked-out branch changed to `herb-embedded-xbi`
  with an uncommitted 131-line README.md diff that wasn't mine — another
  session was actively working the README bead (herb-embedded-xbi) in this
  same git working tree at the same time. It resolved itself (that PR merged
  cleanly, #46), but it's a real hazard: git operations from one session can
  disturb another's checkout. Worth flagging to the user if it happens again
  rather than assuming exclusive ownership of the working tree.
- **The `prismNode` getter contract is more subtle than it looks.** Every
  `AST_ERB_*`/`DocumentNode`'s `.prismNode` getter just does
  `deserializePrismNode(this.prism_node, this.source)` — plain, no unwrapping.
  Ruby's `Prism.dump` can only serialize starting from a full parse (always a
  `ProgramNode` root); there's no public API to dump an arbitrary already-parsed
  node. Rules like `erb-no-silent-statement` (`isAssignmentNode(prismNode)`
  checking `prismNode.constructor.name` directly) or `erb-prefer-direct-output`
  (`isPrismNodeType(prismNode, "StringNode")`) only work because of the
  getter-patching in `ruby_backend.js` that unwraps a single-statement Program
  down to its inner node. This is *our* patch, deliberately scoped to our own
  integration file rather than the vendored bundle — anyone touching prism
  injection later needs to know this exists, since it's easy to assume
  `prismNode` is whatever `Prism.dump` produced raw.
- **`--only <rule>` on the reference CLI ignores `.herb.yml` and
  `defaultConfig.enabled` entirely** — this is what let per-rule conformance
  fixtures exercise not-enabled-by-default rules directly, matching
  `rules: [...]` on the bridge side. Same mechanism gu7/ada's specs already
  relied on for `Bridge#lint`.
- **`bd close` is genuinely reserved for post-merge**, not post-PR-open — this
  came up explicitly with the user twice (`ada`, then `ag7`) as a manual
  "land" step, since there's no actual `/land` command defined in this repo
  (`.claude/commands/` only has `handoff.md`, `ship.md`, `work.md`) despite
  CLAUDE.md referencing one. I did the equivalent by hand each time: pull main,
  `bd close <id> --reason "Merged via PR #N"`, delete the merged local+remote
  branch, `bd dolt push`.

## What I'd do next, and why

- **herb-embedded-5g1** (P3, "Load rubocop-rake and rubocop-rspec plugins") is
  the only ready bead left. Low priority, small — `bundle exec rake` currently
  prints a nag on every run ("RuboCop extension libraries are installed but
  not loaded") for these two, which are already dev dependencies. Quick win
  whenever someone wants a small task.
- **Confirm the actual RubyGems.org listing** — I verified the git tag landed
  on origin but didn't independently verify the `gem push` step actually
  succeeded against RubyGems.org (would need a network call I didn't make).
  Worth a `gem info herb-embedded --remote` or just checking
  https://rubygems.org/gems/herb-embedded once, since `rake release`'s
  tag-and-push and gem-push are separate steps and could in principle diverge
  if something failed silently between them.
- **`.herb.yml` config application** is still the one named gap in CHARTER.md's
  "Open questions" that this session's work didn't touch (only the
  fixture-coverage dimension of the conformance punch list got closed). Not
  urgent, but the next person picking up conformance work should know it's
  still open, distinct from the prism_program/prism_nodes work that's now done.
- Consider pruning the stale local branches listed above — cosmetic, no rush.

## Anything I was uncertain about

- **The "106 vs 100 rules" discrepancy** in `herb-embedded-ag7`'s original
  description got resolved mid-session (the user independently investigated
  and confirmed 100 is correct — 6 files in `src/rules/` are shared
  utility/base modules, not rules). I'd already flagged the same discrepancy
  before the user resolved it; just noting it's genuinely settled now, not an
  open question.
- **Whether `prism_nodes_deep` behaves identically to `prism_nodes` is
  unverified against real behavior** — no rule in the currently-vendored
  bundle actually requests `prism_nodes_deep`, so `ResultEnvelope` treats it
  as an alias by design choice, not by observation. If a future Herb release
  adds a rule using it, worth double-checking the assumption holds.
- **Multi-statement ERB tags** (e.g. `<% a = 1; b = 2 %>`, semicolon-joined in
  one tag) fall back to leaving `prismNode` as the un-unwrapped `ProgramNode`
  in the `ruby_backend.js` patch (only unwraps when `statements.body.length
  === 1`). None of the 100 conformance fixtures happen to exercise this edge
  case, so it's untested — plausible it's fine (rules would just see a
  `ProgramNode` and most type-checks would simply not match, same as today's
  behavior for anything unexpected), but not verified either way.
