# herb-embedded Changelog

Follows [Semantic Versioning](https://semver.org/). Gem version mirrors the vendored
`@herb-tools/linter` version plus a gem-side segment: `0.11.1.N` vendors `@herb-tools/linter@0.11.1`.

---

## unreleased

### Changed

* Upgraded the vendored `@herb-tools/linter` from 0.10.3 to 0.11.1 (and the `herb` gem
  dependency to `~> 0.11.1`). The bundle now registers 170 rules, up from 100, including the
  new Action View, ERB, HTML, SVG, Turbo, and UJS rules and the `herb-*` directive rules.
* `.herb.yml`'s top-level `framework` key is now read and passed to the engine. Rules scoped
  to Action View only run when it is `actionview`; omitting it keeps upstream's `ruby`
  default (and the informational `herb-config-framework-option` diagnostic).
* Explicit rule selection (`--only` / `Bridge#lint(rules:)`) now mirrors upstream's `--only`:
  it bypasses framework, environment, and path filters, since naming a rule is itself the
  answer to whether it should run.
* `ResultEnvelope` forwards the new parser options the 0.11 rule set uses:
  `herb_directives`, `iteration_nodes`, and `erb_openers`.
* The bundle now includes `postcss` for the CSS/scoped-style rules. Its Node-only source-map
  and terminal-color paths are replaced at build time with filesystem-free stubs
  (`stubs/fs.mjs`, `stubs/path.mjs`, etc.), keeping the runtime free of Node built-ins.

### Fixed

* Added the `defaultERBOpenings` callback required by `HerbBackend` in Herb 0.11.

### Conformance

* Added a fixture for every newly registered rule (170 total).
* Two fixtures are marked pending rather than compared: `actionview-no-strict-locals-error`
  and `actionview-no-mistyped-locals` need a project-wide partial index that the standalone
  conformance harness does not build. `actionview-no-void-element-content` and
  `erb-no-javascript-tag-helper` are asserted on the bridge only because upstream 0.11.1's
  CLI computes parser options before merging the config's framework, so it cannot trigger
  them even with `framework: actionview`.

---

## v0.10.3.0 / 18 August 2026

### Added

* Initial release. All 100 Herb lint rules and autofix, no Node required.
