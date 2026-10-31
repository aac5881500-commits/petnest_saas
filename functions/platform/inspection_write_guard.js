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
 * Authorize a read-only handler without granting mutation capabilities.
 * @param {Object} request Verified callable request.
 * @param {Object} db Admin Firestore, injectable in tests.
 * @param {boolean} customer Read the selected booking customer camera.
 * @return {Promise<Object>} Same request, with display/read authorization only.
 */
async function authorizeInspectionRead(request, db, customer = false) {
  const claims = request.auth.token;
  if (!/^[a-f0-9]{48}$/.test(String(claims.inspectionGrant || ""))) {
    throw new https.HttpsError("permission-denied", "查核授權無效");
  }
  const grant = (await db.doc("platform_inspection_previews/" +
      claims.inspectionGrant).get()).data();
  if (!grant || grant.uid !== request.auth.uid || grant.active !== true ||
      grant.rootUid !== "7FNrECQeqAca9Vu8lBBzTSdcJcg1" ||
      grant.expiresAt <= Date.now()) {
    throw new https.HttpsError("unauthenticated", "查核已鎖定");
  }
  const session = (await db.doc("platform_inspection_sessions/" +
      grant.parentSession).get()).data();
  if (!session || session.uid !== grant.rootUid ||
      session.verification !== "email_code_v1" ||
      Date.now() - session.touchedAt >= 1800000) {
    throw new https.HttpsError("unauthenticated", "查核已鎖定");
  }
  let uid = grant.ownerUid;
  if (customer) {
    const id = String((request.data || {}).bookingId || "");
    if (!id || id.includes("/")) {
      throw new https.HttpsError("invalid-argument", "訂單無效");
    }
    const booking = (await db.doc("bookings/" + id).get()).data();
    if (!booking || booking.shopId !== grant.shopId) {
      throw new https.HttpsError("permission-denied", "訂單不屬於查核店家");
    }
    uid = booking.userId;
  } else if ((request.data || {}).shopId !== grant.shopId) {
    throw new https.HttpsError("permission-denied", "不能讀取其他店家");
  }
  // This only authorizes the audited, read-only handler. No owner's token or
  // Firebase Auth account is created, modified, returned or shared.
  return {...request, auth: {...request.auth, uid}};
}
/**
 * Preserve callable metadata and options; mutations are always denied.
 * @param {Object|Function} options Firebase options or handler.
 * @param {Function} handler Original handler.
 * @return {Function} Guarded Firebase callable.
 */
function onCall(options, handler) {
  if (typeof options === "function") {
    handler = options;
    options = {};
  }
  const {inspectionRead = false, inspectionReadActions = null,
    inspectionCustomer = false, ...firebaseOptions} = options;
  return https.onCall(firebaseOptions, async (request, response) => {
    if (request.auth && request.auth.token &&
        request.auth.token.petnestInspection === true) {
      const action = String((request.data || {}).action || "get");
      const allowed = inspectionRead === true ||
        Array.isArray(inspectionReadActions) &&
        inspectionReadActions.includes(action);
      if (!allowed) rejectInspectionWrite(request);
      request = await authorizeInspectionRead(request,
          require("firebase-admin").firestore(), inspectionCustomer);
    }
    return handler(request, response);
  });
}
module.exports = {...https, onCall, rejectInspectionWrite,
  authorizeInspectionRead};
