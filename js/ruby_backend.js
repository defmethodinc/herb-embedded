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
function __herbSelectRules(ruleNames) {
  var wanted = ruleNames && ruleNames.length ? ruleNames : null;

  return HerbLinter.rules.filter(function (ruleClass) {
    return !wanted || wanted.indexOf(ruleClass.ruleName) !== -1;
  });
}

// One Linter per selected rule, each in its own try/catch: a rule that
// throws must not abort the run (spike 2 finding) — the real Linter#lint
// has no such isolation internally, since it runs every selected rule's
// check() in one uncaught loop.
function __herbLint(source, file, ruleNames) {
  var ruleClasses = __herbSelectRules(ruleNames);
  var context = { fileName: file, filename: file };
  var offenses = [];

  ruleClasses.forEach(function (ruleClass) {
    try {
      var linter = new HerbLinter.Linter(__herbEmbeddedBridge.instance, [ruleClass]);
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
