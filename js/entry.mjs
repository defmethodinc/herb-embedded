// Bundle entry point for vendor/herb-linter.js. Imports directly from
// dist/linter.js and dist/rules.js, bypassing @herb-tools/linter's
// package exports map — its exports map only exposes "." (the CLI's
// composed entry point, which pulls in cli.js), "./cli", and "./loader",
// none of which fit. Going straight to the dist files excludes the
// three files with Node built-in references: cli.js, lint-worker.js,
// and custom-rule-loader.js.
export * from "../node_modules/@herb-tools/linter/dist/linter.js";
export * from "../node_modules/@herb-tools/linter/dist/rules.js";

// ParserRule/LexerRule/SourceRule (the base classes custom rules extend)
// live in dist/types.js, which dist/linter.js only partially imports
// (DEFAULT_RULE_CONFIG) without re-exporting the rest. types.js has no
// imports of its own — zero risk of pulling in Node builtins, unlike the
// package's main "." export (dist/index.js), which unconditionally
// imports "fs" and "path".
export * from "../node_modules/@herb-tools/linter/dist/types.js";

// @herb-tools/core's package exports map correctly exposes its ESM entry
// (unlike @herb-tools/linter's), so this needs no exports-map bypass. It's
// already present in the bundle transitively (dist/linter.js imports from
// it internally); re-exporting it by the same specifier lets esbuild
// resolve both to the same module instance rather than duplicating it.
// HerbBackend, ParseResult, LexResult, and friends aren't otherwise
// reachable from outside the bundle's IIFE scope.
export * from "@herb-tools/core";
