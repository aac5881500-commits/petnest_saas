"use strict";
const https = require("firebase-functions/v2/https");
/**
 * Reject every callable mutation for signed inspection identities.
 * @param {Object} request Verified callable request.
 */
function rejectInspectionWrite(request) {
  if (request.auth && request.auth.token &&
      request.auth.token.petnestInspection === true) {
    throw new https.HttpsError("permission-denied", "唯讀查核身分不能修改、刪除、退款、上傳或傳送訊息");
  }
}
/**
 * Preserve callable metadata and options by wrapping the handler.
 * @param {Object|Function} options Firebase options or handler.
 * @param {Function} handler Original handler.
 * @return {Function} Firebase callable with a write guard.
 */
function onCall(options, handler) {
  if (typeof options === "function") {
    handler = options;
    options = {};
  }
  return https.onCall(options, async (request, response) => {
    rejectInspectionWrite(request);
    return handler(request, response);
  });
}
module.exports = {...https, onCall, rejectInspectionWrite};
