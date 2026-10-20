// Bundle entry point for vendor/herb-linter.js. Imports directly from
// dist/index.js, bypassing @herb-tools/linter's package exports map —
// "." resolves to that same file in 0.11, but the public entry point is
// the only stable path across releases. The CLI and lint worker (the
// files full of Node built-in imports) live in dist/cli.js and
// dist/lint-worker.js, which this does not touch; the remaining Node
// references come from postcss and are replaced by build-time stubs (see
// rakelib/bundle.rake).
export * from "../node_modules/@herb-tools/linter/dist/index.js";

// @herb-tools/core's package exports map correctly exposes its ESM entry
// (unlike @herb-tools/linter's), so this needs no exports-map bypass. It's
// already present in the bundle transitively (dist/index.js imports from
// it internally); re-exporting it by the same specifier lets esbuild
// resolve both to the same module instance rather than duplicating it.
// HerbBackend, ParseResult, LexResult, and friends aren't otherwise
// reachable from outside the bundle's IIFE scope.
export * from "@herb-tools/core";
