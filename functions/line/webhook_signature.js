"use strict";
const crypto = require("node:crypto");
/**
 * Verify the unmodified raw webhook bytes before JSON parsing.
 * No endpoint is registered in the preparation phase.
 * @param {Buffer} rawBody Original request body.
 * @param {string} secret Server-side channel secret.
 * @param {string} signature x-line-signature value.
 * @return {boolean} Whether the signature matches.
 */
function verifyLineSignature(rawBody, secret, signature) {
  if (!Buffer.isBuffer(rawBody) || typeof secret !== "string" || !secret ||
      typeof signature !== "string" ||
      !/^[A-Za-z0-9+/]{43}=$/.test(signature)) {
    return false;
  }
  const received = Buffer.from(signature, "base64");
  const expected = crypto.createHmac("sha256", secret).update(rawBody).digest();
  return received.length === expected.length &&
    crypto.timingSafeEqual(received, expected);
}
module.exports = {verifyLineSignature};
