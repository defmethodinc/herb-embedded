// Stands in for Node's "fs" module when bundling postcss for the bare V8
// runtime. Only postcss's PreviousMap (source-map loading) imports it, and
// that path is unreachable when parsing in-memory CSS with no `from`
// option — as the linter does. Reporting "nothing on disk" matches a
// filesystem-free engine honestly rather than pretending reads succeeded.
export function existsSync() {
  return false;
}

export function readFileSync() {
  throw new Error("herb-embedded: filesystem access is unavailable in the embedded engine");
}

export function realpathSync(path) {
  return path;
}
