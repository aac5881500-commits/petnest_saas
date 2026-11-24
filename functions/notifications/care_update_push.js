/* eslint-disable require-jsdoc, max-len */
"use strict";
const admin = require("firebase-admin");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {customerPushAllowed} = require("./customer_push_policy");

async function deliverCareUpdate(notice, db, messaging) {
  const data = notice && notice.data;
  if (!data || data.section !== "care" ||
      !["medication", "service"].includes(data.careKind) ||
      !notice.userId || !notice.bookingId) return;
  const user = db.collection("users").doc(notice.userId);
  const settings = await user.collection("notification_settings").doc("global").get();
  if (!customerPushAllowed({category: "transactional", isMandatory: true},
      settings.data() || {}, notice.shopId)) return;
  const snapshot = await user.collection("fcm_tokens").get();
  const tokens = snapshot.docs.filter((doc) => doc.id && doc.data().enabled !== false)
      .map((doc) => doc.id);
  const payload = Object.fromEntries(Object.entries(data)
      .filter(([, value]) => value != null).map(([key, value]) => [key, String(value)]));
  for (let offset = 0; offset < tokens.length; offset += 500) {
    await messaging.sendEachForMulticast({
      tokens: tokens.slice(offset, offset + 500),
      notification: {title: notice.title, body: notice.body},
      data: payload,
      android: {priority: "high", notification: {sound: "default"}},
      apns: {payload: {aps: {sound: "default"}}},
    });
  }
}

exports.deliverCareUpdate = deliverCareUpdate;
exports.sendCareUpdatePush = onDocumentCreated({
  document: "notifications/{notificationId}", region: "asia-east1",
}, async (event) => {
  const notice = event.data && event.data.data();
  await deliverCareUpdate(notice, admin.firestore(), admin.messaging());
});
