// Stands in for Node's "url" module when bundling postcss for the bare V8
// runtime. postcss guards every use with `if (pathToFileURL)` /
// `if (fileURLToPath)`, so exporting them as undefined disables its
// file-URL handling without pretending URLs are supported.
export const fileURLToPath = undefined;
export const pathToFileURL = undefined;
