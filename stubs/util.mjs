// Stands in for Node's "util" module when bundling for the bare V8
// runtime. The only consumer is util-deprecate (via source-map-js's Node
// entry), which wraps a function to emit a one-time deprecation warning
// — irrelevant here, so the wrapper is the identity.
export function deprecate(fn) {
  return fn;
}
