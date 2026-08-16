// Minimal UTF-8 TextDecoder/TextEncoder for bare V8 embeddings (e.g.
// mini_racer), which provide ECMAScript but not WHATWG host APIs.
//
// Strict on purpose: real TextDecoder throws on non-buffer input rather
// than coercing it. A shim that coerces turns loud failures into silent
// ones — decode("a string") must throw, not return empty output.
(function (global) {
  "use strict";

  function toUint8Array(input) {
    if (input instanceof Uint8Array) {
      return input;
    }
    if (input instanceof ArrayBuffer) {
      return new Uint8Array(input);
    }
    if (ArrayBuffer.isView(input)) {
      return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
    }
    throw new TypeError(
      "Failed to execute 'decode': The provided value is not of type " +
        "'(ArrayBuffer or ArrayBufferView)'"
    );
  }

  class TextDecoder {
    constructor(encoding) {
      if (encoding !== undefined && encoding !== "utf-8" && encoding !== "utf8") {
        throw new RangeError("TextDecoder only supports utf-8");
      }
      this.encoding = "utf-8";
    }

    decode(input) {
      const bytes = toUint8Array(input);
      let result = "";
      let i = 0;

      while (i < bytes.length) {
        const byte1 = bytes[i];
        let codePoint;
        let extraBytes;

        if (byte1 < 0x80) {
          codePoint = byte1;
          extraBytes = 0;
        } else if ((byte1 & 0xe0) === 0xc0) {
          codePoint = byte1 & 0x1f;
          extraBytes = 1;
        } else if ((byte1 & 0xf0) === 0xe0) {
          codePoint = byte1 & 0x0f;
          extraBytes = 2;
        } else if ((byte1 & 0xf8) === 0xf0) {
          codePoint = byte1 & 0x07;
          extraBytes = 3;
        } else {
          throw new TypeError("Invalid UTF-8 byte sequence");
        }

        for (let j = 0; j < extraBytes; j++) {
          i++;
          const nextByte = bytes[i];
          if (nextByte === undefined || (nextByte & 0xc0) !== 0x80) {
            throw new TypeError("Invalid UTF-8 continuation byte");
          }
          codePoint = (codePoint << 6) | (nextByte & 0x3f);
        }

        if (codePoint > 0xffff) {
          codePoint -= 0x10000;
          result += String.fromCharCode(
            0xd800 + (codePoint >> 10),
            0xdc00 + (codePoint & 0x3ff)
          );
        } else {
          result += String.fromCharCode(codePoint);
        }

        i++;
      }

      return result;
    }
  }

  class TextEncoder {
    constructor() {
      this.encoding = "utf-8";
    }

    encode(input) {
      if (typeof input !== "string") {
        throw new TypeError(
          "Failed to execute 'encode': parameter 1 is not of type 'string'."
        );
      }

      const bytes = [];

      for (let i = 0; i < input.length; i++) {
        let codePoint = input.charCodeAt(i);

        if (codePoint >= 0xd800 && codePoint <= 0xdbff && i + 1 < input.length) {
          const next = input.charCodeAt(i + 1);
          if (next >= 0xdc00 && next <= 0xdfff) {
            codePoint = (codePoint - 0xd800) * 0x400 + (next - 0xdc00) + 0x10000;
            i++;
          }
        }

        if (codePoint < 0x80) {
          bytes.push(codePoint);
        } else if (codePoint < 0x800) {
          bytes.push(0xc0 | (codePoint >> 6), 0x80 | (codePoint & 0x3f));
        } else if (codePoint < 0x10000) {
          bytes.push(
            0xe0 | (codePoint >> 12),
            0x80 | ((codePoint >> 6) & 0x3f),
            0x80 | (codePoint & 0x3f)
          );
        } else {
          bytes.push(
            0xf0 | (codePoint >> 18),
            0x80 | ((codePoint >> 12) & 0x3f),
            0x80 | ((codePoint >> 6) & 0x3f),
            0x80 | (codePoint & 0x3f)
          );
        }
      }

      return new Uint8Array(bytes);
    }
  }

  global.TextDecoder = TextDecoder;
  global.TextEncoder = TextEncoder;
})(typeof globalThis !== "undefined" ? globalThis : this);
