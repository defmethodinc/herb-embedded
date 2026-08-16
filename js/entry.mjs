// Bundle entry point for vendor/herb-linter.js. Imports directly from
// dist/linter.js and dist/rules.js, bypassing @herb-tools/linter's
// package exports map — its exports map only exposes "." (the CLI's
// composed entry point, which pulls in cli.js), "./cli", and "./loader",
// none of which fit. Going straight to the dist files excludes the
// three files with Node built-in references: cli.js, lint-worker.js,
// and custom-rule-loader.js.
export * from "../node_modules/@herb-tools/linter/dist/linter.js";
export * from "../node_modules/@herb-tools/linter/dist/rules.js";
