// Stands in for @herb-tools/config in the vendored bundle. The real
// package reads .herb.yml from disk (fs/path), which isn't available
// in a bare V8 context and isn't needed here — this gem reads config
// on the Ruby side (Task 8). Only resolveSeverity, the one export
// @herb-tools/linter's linter.js actually imports, is reproduced here,
// verbatim from @herb-tools/config@0.10.3's own implementation.
export function resolveSeverity(severity, mode) {
  if (typeof severity === "string") return severity;
  return severity[mode];
}
