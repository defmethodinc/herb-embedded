// Wires the vendored @herb-tools/linter bundle to Ruby. Must load after
// vendor/herb-linter.js and after the six rbXxx callbacks below are
// attached (Bridge#boot handles the ordering).
//
// HerbBackend (from @herb-tools/core) must be subclassed: its `version`
// getter calls the abstract backendVersion(), which the base class
// doesn't implement. Instantiating HerbBackend directly fails.
var libHerbBackend = {
  parse: function (source, options) {
    return JSON.parse(rbParse(source, options));
  },
  lex: function (source) {
    return JSON.parse(rbLex(source));
  },
  extractRuby: function (source, options) {
    return rbExtractRuby(source, options);
  },
  extractHTML: function (source) {
    return rbExtractHTML(source);
  },
  parseRuby: function (source) {
    return rbParseRuby(source);
  },
  version: function () {
    return rbVersion();
  },
  diff: function () {
    throw new Error("diff is not implemented by the Ruby backend");
  },
};

// rbParse (via ResultEnvelope#inject_prism_nodes) injects prism_node bytes
// produced by Ruby's Prism.dump, which always serializes a whole
// ProgramNode — there is no public API to dump an arbitrary sub-node
// directly. But every prism_nodes-dependent rule (see CHARTER.md) expects
// an ERB*Node's prismNode to BE the single embedded-Ruby expression node
// itself (e.g. isAssignmentNode checks prismNode.constructor.name), not a
// Program wrapping it. Unwrap here, once, for every ERB node class that
// defines the prismNode getter, rather than patching the vendored bundle.
// Only unwraps when the parse yielded exactly one top-level statement —
// the case single-tag Ruby content always produces — leaving anything
// else (multiple ';'-separated statements in one tag) as the ProgramNode,
// same as an unhandled edge case would fall back to.
Object.keys(HerbLinter).forEach(function (name) {
  if (!/^ERB.*Node$/.test(name)) return;

  var proto = HerbLinter[name] && HerbLinter[name].prototype;
  var descriptor = proto && Object.getOwnPropertyDescriptor(proto, "prismNode");
  if (!descriptor || typeof descriptor.get !== "function") return;

  var originalGet = descriptor.get;

  Object.defineProperty(proto, "prismNode", {
    configurable: true,
    enumerable: descriptor.enumerable,
    get: function () {
      var raw = originalGet.call(this);
      var body = raw && raw.constructor && raw.constructor.name === "ProgramNode" && raw.statements && raw.statements.body;

      return body && body.length === 1 ? body[0] : raw;
    },
  });
});

class RubyBackend extends HerbLinter.HerbBackend {
  backendVersion() {
    return "mini_racer";
  }
}

// A Promise returned directly from a Ruby<->JS call marshals to Ruby as
// {} — mini_racer doesn't drive V8's microtask queue on its own timeline,
// only between separate eval/call invocations. So boot is a two-step
// handshake: this call kicks off the async load without awaiting it;
// Bridge#boot observes __herbEmbeddedBridge.ready in a second, separate
// call, by which point the microtask queue has drained and the promise
// has resolved.
var __herbEmbeddedBridge = {
  instance: new RubyBackend(function () {
    return Promise.resolve(libHerbBackend);
  }),
  ready: false,
  error: null,
};

__herbEmbeddedBridge.instance
  .load()
  .then(function () {
    __herbEmbeddedBridge.ready = true;
  })
  .catch(function (e) {
    __herbEmbeddedBridge.error = String(e && e.message ? e.message : e);
  });

function __herbRuleNames() {
  return HerbLinter.rules.map(function (ruleClass) {
    return ruleClass.ruleName;
  });
}

// Rule selection happens before execution: Linter's constructor takes an
// explicit rules array, so an unselected rule is never instantiated or
// checked, not merely filtered out of the offenses it already produced.
// With no explicit selection, match upstream's own default: only rules
// enabled by their own defaultConfig (Linter.filterRulesByConfig with no
// user config still filters on that), not every available rule class.
// An explicit selection bypasses that filtering entirely — matching
// --only's real semantics — so a caller can still opt into a
// not-enabled-by-default rule by naming it.
function __herbSelectRules(ruleNames) {
  var wanted = ruleNames && ruleNames.length ? ruleNames : null;

  if (!wanted) {
    return HerbLinter.Linter.filterRulesByConfig(HerbLinter.rules).enabled;
  }

  return HerbLinter.rules.filter(function (ruleClass) {
    return wanted.indexOf(ruleClass.ruleName) !== -1;
  });
}

// Registers a custom rule from Ruby-rewritten source (see
// CustomRuleLoader.rewrite): an IIFE expression that destructures its
// base class from HerbLinter and returns the rule class. A rule sharing
// a ruleName with an existing one (built-in or previously-registered
// custom) replaces it in place, matching upstream's override behavior —
// the caller (CustomRuleLoader#load_all) is told via `overrode` so it can
// warn on the Ruby side.
function __herbRegisterCustomRule(rewrittenSource, path) {
  var RuleClass;

  try {
    RuleClass = eval(rewrittenSource);
  } catch (e) {
    throw new Error("Failed to evaluate custom rule at " + path + ": " + (e && e.message ? e.message : String(e)));
  }

  if (!RuleClass || typeof RuleClass !== "function" || typeof RuleClass.ruleName !== "string" || typeof RuleClass.prototype.check !== "function") {
    throw new Error("No valid default export found in " + path + ". Custom rules must use default export.");
  }

  var existingIndex = HerbLinter.rules.findIndex(function (ruleClass) {
    return ruleClass.ruleName === RuleClass.ruleName;
  });
  var overrode = existingIndex !== -1;

  if (overrode) {
    HerbLinter.rules.splice(existingIndex, 1, RuleClass);
  } else {
    HerbLinter.rules.push(RuleClass);
  }

  return { ruleName: RuleClass.ruleName, overrode: overrode };
}

// A single Linter across all selected rules, matching upstream's own
// lint-then-fix composition (Linter#autofix mutates a running source as
// it walks offenses from every selected rule together, unlike #lint's
// per-rule crash isolation). The parse-doesn't-break safety check lives
// on the Ruby side (Bridge#autofix), since it just needs Herb.parse.
function __herbAutofix(source, file, ruleNames, includeUnsafe) {
  var ruleClasses = __herbSelectRules(ruleNames);
  var context = { fileName: file, filename: file };
  var linter = new HerbLinter.Linter(__herbEmbeddedBridge.instance, ruleClasses, undefined, HerbLinter.rules);
  var result = linter.autofix(source, context, undefined, { includeUnsafe: !!includeUnsafe });

  return JSON.stringify({ source: result.source, fixed: result.fixed });
}

// One Linter per selected rule, each in its own try/catch: a rule that
// throws must not abort the run (spike 2 finding) — the real Linter#lint
// has no such isolation internally, since it runs every selected rule's
// check() in one uncaught loop.
//
// The 4th constructor arg (allAvailableRules) must be the full registry,
// not just the one rule being run: herb-disable-comment-unnecessary reads
// context.validRuleNames (built from Linter#getAvailableRules, which
// falls back to allAvailableRules) to decide whether a `herb:disable
// some-other-rule` comment references a real rule — omitting this arg
// left validRuleNames scoped to whatever single rule __herbLint happened
// to be running, so the rule silently never matched anything outside
// itself. Caught by conformance fixture coverage (herb-embedded-ag7).
function __herbLint(source, file, ruleNames) {
  var ruleClasses = __herbSelectRules(ruleNames);
  var context = { fileName: file, filename: file };
  var offenses = [];

  ruleClasses.forEach(function (ruleClass) {
    try {
      var linter = new HerbLinter.Linter(__herbEmbeddedBridge.instance, [ruleClass], undefined, HerbLinter.rules);
      var result = linter.lint(source, context);
      offenses = offenses.concat(result.offenses);
    } catch (e) {
      offenses.push({
        rule: ruleClass.ruleName,
        message: "Rule '" + ruleClass.ruleName + "' crashed: " + (e && e.message ? e.message : String(e)),
        severity: "error",
        location: null,
      });
    }
  });

  return JSON.stringify(offenses);
}
