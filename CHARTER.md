# herb-embedded — Charter

## What this is

herb-embedded runs [Herb](https://herb-tools.dev)'s real HTML+ERB lint rules — all 107 of
them, spanning accessibility, Action View, ERB, HTML, SVG, Turbo, and UJS, plus autofix —
in a pure Ruby process, with no Node.js required at runtime. It does this by vendoring
Herb's rule engine as JavaScript and executing it in-process through a pluggable embedded
JS engine (mini_racer/V8 as the reference adapter), while Ruby owns parsing (via the `herb`
gem's native C extension and stdlib Prism), file discovery, and configuration. No rules are
ported to Ruby, so none diverge from upstream — a future Herb release's rule changes arrive
by resyncing the vendored bundle, not by rewriting anything.

## Who it's for

Ruby/Rails teams who have deliberately kept Node out of their stack — for example,
importmap-rails plus tailwindcss-rails via the precompiled `tailwindcss-ruby` binary gem —
and therefore cannot use Herb's linter today. Every existing Ruby-side path dead-ends at
Node: the `herb` gem's own `herb lint` shells out to `npx @herb-tools/linter`,
`pronto-herb` does the same via `Open3.capture3`, and `rubocop-herb` is an empty
placeholder. Before this gem, those teams either installed Node solely to run a linter, or
went without Herb's lint rules entirely — even though a Node-free HTML+ERB parser was
already sitting in the `herb` gem's native C extension the whole time.

## What "good" means here

- **Rule fidelity, not reimplementation.** The job is to make the real Herb rule set run in
  Ruby, not to write a Ruby-flavored rule set. If a rule behaves differently from
  `npx @herb-tools/linter`, that's a bridge bug, never an acceptable "Ruby version" of the
  rule.
- **No Node at runtime, full stop.** Node is a build-time tool for producing the vendored
  bundle — the same relationship `tailwindcss-ruby` has with the Tailwind toolchain. Any
  runtime code path that shells out, spawns a process, or touches `node_modules` is a
  defect.
- **Loud failure over silent drift.** The single highest risk this project runs is silent
  AST drift — a future `herb` gem release changes node shapes, rules just stop matching,
  and a green run becomes indistinguishable from a working one. Version gating against a
  recorded validated set, shims that throw instead of coerce, and exceptions that get
  caught rather than swallowed all exist to fail loudly at the earliest possible point.
- **A narrow, pluggable engine boundary.** `EngineAdapter` is four methods. mini_racer is
  the reference implementation, not a hard dependency baked through the rest of the
  codebase — a future QuickJS, Wasmtime, or vendored-binary adapter should only have to
  implement that port.
- **Field-compatible with upstream's own eventual shape.** `Diagnostic` / `LintResult` /
  `Report` match the shape of `Herb::Diagnostic` / `Herb::LintResult` as drafted in upstream
  [marcoroth/herb#455](https://github.com/marcoroth/herb/pull/455), so this composes with —
  rather than competes against — wherever Herb's own Ruby story ends up.

## Out of scope

- **Porting rules to Ruby.** The 107 rules are imperative TypeScript, not data. Porting them
  forks the rule set the day it ships and it diverges from there.
- **`herb format`.** The formatter is a separate package with its own semantics, and
  formatter bugs are more visible than linter bugs because they rewrite whole files.
- **Modifying the `herb` gem, or taking over marcoroth/herb#455.** herb-embedded composes
  with the published `herb` gem, unmodified. It does not fork Herb, and it does not adopt or
  resolve conflicts on someone else's dormant personal draft branch.
- **Parallelism across files, in v1.** mini_racer releases the GVL during JS execution and
  documents threadsafe `Context` usage, so this is a deliberate deferral for a later version,
  not a structural limitation — correctness and conformance come first.
- **Arbitrary ESM in custom rules.** `.herb/rules/*.mjs` loading supports exactly the
  documented import surface (`@herb-tools/linter`), rewritten at load time. Anything
  importing outside that surface fails loudly with a named error, not a mysterious
  `ReferenceError`.
- **Windows support on the reference adapter.** `libv8-node` ships no Windows build at all.
  Windows users need a different adapter — the vendored-binary approach stays alive as a
  future fallback option for exactly this reason, rather than being discarded.

## Shape decisions

- **AST crosses the bridge as JSON; Prism crosses as binary.** Ruby parses natively via
  `Herb.parse` and serializes to JSON for the engine — the rejected alternative (running
  libherb's WASM build inside the engine) duplicates the parser and forces WASM support onto
  every future adapter. Prism-backed rules need real walkable `PrismNode` objects, not JSON,
  so `Prism.dump`'s self-describing versioned binary format crosses as a `Uint8Array` via
  `MiniRacer::Binary` — verified byte-accurate including non-ASCII source.
- **Exceptions cross the boundary raw, not as structured errors.** An earlier design assumed
  exceptions needed to be caught and translated before crossing. Sixteen probes showed raw
  crossing is catchable, non-poisoning, and preserves the original Ruby class in the outward
  direction, so `Bridge` just lets them cross and catches in JS. One real asymmetry: inward
  (Ruby → JS catch), the exception class flattens to a generic `Error` and only the message
  survives — anything JS needs to branch on gets encoded into the message via a tagged
  prefix.
- **Version gating targets a recorded validated set, not a semver position.** Herb is
  pre-1.0 and ships every few months (0.8 → 0.9 → 0.10), so "refuse on unvalidated major"
  gates nothing under 0.x semver. `Bundle` records the exact `herb` gem versions it was
  validated against; `Bridge` checks at boot against that set.
- **Gem version mirrors the vendored linter version, plus a gem-side segment:**
  `herb-embedded 0.10.3.N` vendors `@herb-tools/linter@0.10.3`. `Gemfile.lock` then answers
  "which rules do I have" unambiguously.
- **Namespace `Herb::Embedded`; executable `herb-lint-rb`.** The `-rb` suffix lets it coexist
  with the npm `herb-lint` binary rather than shadowing it.
- **This is a deliberately interim, sunset-able gem, not a permanent fork of Herb's Ruby
  story.** Marco Roth (Herb's maintainer) is building his own `herb-linter` gem, likely
  wired through `Herb.lint` on the main `herb` gem, and expects it to eventually supersede
  marcoroth/herb#455 (see [marcoroth/herb#2215](https://github.com/marcoroth/herb/issues/2215)).
  herb-embedded proceeds anyway: it's useful now, both for defmethod and for anyone else who
  needs Node-free Herb linting today, and a running, tested implementation is also useful
  input for Marco as he builds his own — he can see what works and what doesn't. **When the
  official `herb-linter` gem ships, herb-embedded sunsets in its favor.**
- **Testing is RSpec.** The original implementation plan specified minitest, but the repo has
  used RSpec consistently since Task 1 — every spec file, the Gemfile, and the Rakefile agree
  on it. Recorded here as the actual decision, superseding the plan.
- **Supply-chain controls live at the one place third-party code enters the process:** the
  scheduled bundle-rebuild job. Pin by npm integrity hash (not version string alone), a human
  reads the bundle diff before merge, and autofix output — the one thing the sandboxed engine
  can influence outside itself — is always re-parsed before Ruby writes it to disk.
- **The engine gets no filesystem and no network.** Its entire surface is two callbacks
  (`rubyParse`, `rubyParseRuby`) that take a source string and return parse data. This is
  deliberate and load-bearing for the supply-chain story above, not incidental.

## Open questions

1. **When does "sunset" actually trigger?** The decision to sunset in favor of Marco's
   `herb-linter` once it ships is made (see Shape decisions), but "ships" isn't yet defined —
   a first release, a stable release, feature parity with what herb-embedded covers today, or
   something else. Worth pinning down once his gem has an actual release to evaluate against,
   not before.
2. **Gem namespace and executable name could still collide.** `Herb::Embedded` /
   `herb-lint-rb` are the current names. If Marco's gem claims `Herb::Linter` or a
   conflicting convention before herb-embedded sunsets, a rename may be needed in the
   meantime — low stakes given the planned sunset, but worth a glance when his gem surfaces.
3. **Conformance punch list isn't closed.** The design spec's differential run against
   `npx @herb-tools/linter` wasn't yet clean end-to-end — missing `LintContext` (filename),
   missing `.herb.yml` config application, and per-rule `parserOptions` forwarding. Each has
   a named cause and is tracked as implementation work in `bd` (see `herb-embedded-6dp` and
   related beads), not a design gap.
4. **Config schema stability.** `.herb.yml` config currently passes through to the engine
   whole. Per-rule options can change across Herb releases, so Ruby may eventually need
   version-aware translation instead of passthrough. Unresolved until it's actually observed
   happening.
