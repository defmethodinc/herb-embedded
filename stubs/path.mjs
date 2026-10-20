// Stands in for Node's "path" module when bundling postcss for the bare
// V8 runtime. The linter only calls postcss.parse(css) with no `from`
// option, so none of postcss's source-map path handling is reachable;
// these implementations exist to satisfy postcss's module-level
// `pathAvailable` feature check and its (unused) code paths. Pure POSIX
// string handling — never touches a filesystem.
export function isAbsolute(path) {
  return path.startsWith("/");
}

export function resolve(...parts) {
  const joined = parts.filter(Boolean).join("/").replace(/\/+/g, "/");
  return joined.startsWith("/") ? joined : "/" + joined;
}

export function dirname(path) {
  const index = path.lastIndexOf("/");
  return index <= 0 ? "/" : path.slice(0, index);
}

export function join(...parts) {
  return parts.filter(Boolean).join("/").replace(/\/+/g, "/");
}

export function relative(from, to) {
  if (to.startsWith(from + "/")) return to.slice(from.length + 1);
  return to;
}

export const sep = "/";
