# herb-embedded

Lints ERB templates with [Herb](https://herb-tools.dev)'s actual rule set — 100 built-in
rules spanning accessibility, Action View, ERB, HTML, SVG, and Turbo markup, plus autofix —
as a plain Ruby dependency. Nothing shells out to Node while it runs.

Herb itself is JS-first: `herb lint` shells out to `npx @herb-tools/linter` under the hood,
and the other Ruby-side integrations either do the same (`pronto-herb`) or aren't implemented
yet (`rubocop-herb`). That's a dead end for a Rails app that has deliberately kept Node off
its stack — importmap-rails plus the precompiled `tailwindcss-ruby` binary being the usual
reason. herb-embedded gets around it by vendoring Herb's real TypeScript rule engine and
running it inside an embedded JS engine (V8, via mini_racer) from within your Ruby process —
so you get the actual upstream rules, not a Ruby reimplementation of them, without installing
Node anywhere. Full rationale and scope in [CHARTER.md](CHARTER.md).

## Install

Not yet published to rubygems.org — add it straight from GitHub:

```ruby
# Gemfile
gem "herb-embedded", git: "https://github.com/defmethodinc/herb-embedded.git"
```

```bash
bundle install
```

Or build and install it locally from a clone:

```bash
git clone https://github.com/defmethodinc/herb-embedded.git
cd herb-embedded
bundle install
bundle exec rake build
gem install pkg/herb-embedded-*.gem
```

## Usage

Lint every file your config (or the defaults) picks up:

```bash
bundle exec herb-lint-rb
```

With no arguments, herb-lint-rb discovers files itself, from `.herb.yml`'s
`files.include`/`files.exclude` globs (default: `**/*.html.erb` and `**/*.herb` under the
current directory) — it does not accept a directory as an argument. Pass explicit file paths
instead to lint a subset:

```bash
bundle exec herb-lint-rb app/views/widgets/_card.html.erb app/views/widgets/_footer.html.erb
```

Exit codes: `0` clean, `1` offenses found at or above the fail level, `2` a config/flag error.

## CLI flags

| Flag | Effect |
| --- | --- |
| `--fix` | Apply safe autocorrections |
| `--fix-unsafely` | Apply unsafe autocorrections too (implies `--fix`) |
| `--format FORMAT` | `detailed` \| `simple` \| `json` \| `github` (default: `detailed`) |
| `--fail-level LEVEL` | `error` \| `warning` \| `info` \| `hint` — minimum severity that fails the run (default from `.herb.yml`'s `linter.fail_level`, itself defaulting to `error`) |
| `--only RULE` | Run only this rule (repeatable) |
| `--init` | Write a starter `.herb.yml` pinning the currently bundled linter version |
| `--version` | Print the herb-embedded and bundled `@herb-tools/linter` versions |
| `-h`, `--help` | Show help |

## Configuring `.herb.yml`

`bundle exec herb-lint-rb --init` writes a starter file:

```yaml
version: "0.10.3"
files:
  include:
    - "**/*.html.erb"
    - "**/*.herb"
  exclude: []
linter:
  fail_level: error
  rules: {}
```

- `version` records which bundled linter version the file was generated against; it's
  informational, not enforced.
- `files.include` / `files.exclude` are glob lists (relative to the directory `herb-lint-rb`
  runs from) that control which files a no-argument run discovers.
- `linter.fail_level` sets the default minimum severity that produces a non-zero exit code
  (overridable per-run with `--fail-level`).
- `linter.rules.<rule-name>.enabled: false` disables a built-in rule:

  ```yaml
  linter:
    rules:
      html-no-self-closing:
        enabled: false
  ```

Only these keys are read; any other key from upstream `@herb-tools/config`'s schema is parsed
but ignored, not an error.

## Custom rules

Drop `.mjs` files under `.herb/rules/`. The only supported import is named imports from
`@herb-tools/linter` (rewritten at load time to pull from the already-loaded bundle — nothing
else can be imported, and an unsupported import fails loudly instead of producing a runtime
`ReferenceError`):

```js
// .herb/rules/my_custom_rule.mjs
import { ParserRule } from "@herb-tools/linter";

export default class MyCustomRule extends ParserRule {
  static ruleName = "my-custom-rule";

  check(result, context) {
    return [this.createOffense("Custom offense!", result.value.location)];
  }
}
```

A custom rule whose `ruleName` matches a built-in rule replaces it for that run (and prints a
warning to stderr).

## Learn more

[CHARTER.md](CHARTER.md) covers what this gem is, who it's for, what "good" means here, and
what's explicitly out of scope — read that before proposing a change to its shape.
[CONTRIBUTING.md](CONTRIBUTING.md) covers development setup.
