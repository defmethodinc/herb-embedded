// Stands in for picocolors when bundling postcss for the bare V8 runtime.
// The embedded engine's output is never a TTY and herb-embedded's own
// formatters own color choices on the Ruby side, so every color function
// is the identity. postcss only consults these from CssSyntaxError
// formatting.
const identity = (value) => value;

export const isColorSupported = false;
export const createColors = () => colorSet;

export const reset = identity;
export const bold = identity;
export const dim = identity;
export const italic = identity;
export const underline = identity;
export const inverse = identity;
export const hidden = identity;
export const strikethrough = identity;
export const black = identity;
export const red = identity;
export const green = identity;
export const yellow = identity;
export const blue = identity;
export const magenta = identity;
export const cyan = identity;
export const white = identity;
export const gray = identity;
export const grey = identity;
export const blackBright = identity;
export const redBright = identity;
export const greenBright = identity;
export const yellowBright = identity;
export const blueBright = identity;
export const magentaBright = identity;
export const cyanBright = identity;
export const whiteBright = identity;
export const bgBlack = identity;
export const bgRed = identity;
export const bgGreen = identity;
export const bgYellow = identity;
export const bgBlue = identity;
export const bgMagenta = identity;
export const bgCyan = identity;
export const bgWhite = identity;
export const bgBlackBright = identity;
export const bgRedBright = identity;
export const bgGreenBright = identity;
export const bgYellowBright = identity;
export const bgBlueBright = identity;
export const bgMagentaBright = identity;
export const bgCyanBright = identity;
export const bgWhiteBright = identity;

const colorSet = {
  isColorSupported,
  createColors,
  reset,
  bold,
  dim,
  italic,
  underline,
  inverse,
  hidden,
  strikethrough,
  black,
  red,
  green,
  yellow,
  blue,
  magenta,
  cyan,
  white,
  gray,
  grey,
  blackBright,
  redBright,
  greenBright,
  yellowBright,
  blueBright,
  magentaBright,
  cyanBright,
  whiteBright,
  bgBlack,
  bgRed,
  bgGreen,
  bgYellow,
  bgBlue,
  bgMagenta,
  bgCyan,
  bgWhite,
  bgBlackBright,
  bgRedBright,
  bgGreenBright,
  bgYellowBright,
  bgBlueBright,
  bgMagentaBright,
  bgCyanBright,
  bgWhiteBright,
};

export default colorSet;
