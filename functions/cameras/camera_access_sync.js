// 檔案名稱：functions/cameras/camera_access_sync.js
// 功能說明：退房、換房、設備移房或停用時，依最新申請狀態同步分享待辦。

const admin = require("firebase-admin");
const {
  onDocumentDeleted,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {normalizeString} = require("../daycare/daycare_utils");
const policy = require("./camera_access_policy");

const region = "asia-east1";

/**
 * @param {string} shopId 店家
 * @param {string} field 欄位
 * @param {string} value 值
 * @return {Promise<Array<string>>}
 */
async function loadRequestIds(shopId, field, value) {
  const snap = await admin.firestore()
      .collection("shops")
      .doc(shopId)
      .collection("camera_access_requests")
      .where(field, "==", value)
      .get();
  return snap.docs.map((doc) => doc.id);
}

/**
 * 交易內重讀申請與最新來源，失敗會拋出讓 Cloud Functions 重試。
 * @param {string} shopId 店家
 * @param {string} requestId 申請
 * @param {Function} loadContext 讀取最新訂單、設備或店家
 * @return {Promise<void>}
 */
async function commitRequest(shopId, requestId, loadContext) {
  const firestore = admin.firestore();
  const ref = firestore
      .collection("shops")
      .doc(shopId)
      .collection("camera_access_requests")
      .doc(requestId);
  await firestore.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists) {
      return;
    }
    const latest = {id: snap.id, ...(snap.data() || {})};
    const context = await loadContext(transaction, latest);
    const reason = policy.requestSyncReason(latest, context || {});
    const write = policy.commitSyncWrite(
        latest,
        reason,
        new Date().toISOString(),
    );
    if (!write) {
      return;
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    const patch = {
      status: write.status,
      updatedAt: now,
    };
    if (write.revocationReason) {
      patch.revocationReason = write.revocationReason;
    }
    if (write.closeReason) {
      patch.closeReason = write.closeReason;
    }
    if (write.revocationRequestedAt) {
      patch.revocationRequestedAt = now;
    }
    if (write.closedAt) {
      patch.closedAt = now;
    }
    transaction.set(ref, patch, {merge: true});
  });
}

/**
 * @param {string} shopId 店家
 * @param {Array<string>} ids 申請編號
 * @param {Function} loadContext 讀取最新來源
 * @return {Promise<void>}
 */
async function commitMany(shopId, ids, loadContext) {
  for (const requestId of ids) {
    await commitRequest(shopId, requestId, loadContext);
  }
}

exports.syncCameraAccessOnBooking = onDocumentUpdated(
    {document: "bookings/{bookingId}", region},
    async (event) => {
      if (!event.data) {
        return;
      }
      const before = event.data.before.data() || {};
      const after = event.data.after.data() || {};
      const shopId = normalizeString(after.shopId || before.shopId);
      const bookingId = event.params.bookingId;
      if (!shopId || !bookingId) {
        return;
      }
      const ids = await loadRequestIds(shopId, "bookingId", bookingId);
      const bookingRef = admin.firestore()
          .collection("bookings")
          .doc(bookingId);
      await commitMany(shopId, ids, async (transaction) => {
        const live = await transaction.get(bookingRef);
        return {booking: live.data() || {}};
      });
    },
);

exports.syncCameraAccessOnDevice = onDocumentUpdated(
    {document: "shops/{shopId}/devices/{deviceId}", region},
    async (event) => {
      if (!event.data) {
        return;
      }
      const before = event.data.before.data() || {};
      const after = event.data.after.data() || {};
      if (String(before.type || "") !== "camera" &&
          String(after.type || "") !== "camera") {
        return;
      }
      const shopId = event.params.shopId;
      const deviceId = event.params.deviceId;
      const ids = await loadRequestIds(shopId, "deviceId", deviceId);
      const deviceRef = admin.firestore()
          .collection("shops")
          .doc(shopId)
          .collection("devices")
          .doc(deviceId);
      const shopRef = admin.firestore().collection("shops").doc(shopId);
      await commitMany(shopId, ids, async (transaction) => {
        const deviceSnap = await transaction.get(deviceRef);
        const shopSnap = await transaction.get(shopRef);
        const device = deviceSnap.exists ?
          {id: deviceId, ...(deviceSnap.data() || {})} :
          {id: deviceId, type: "camera", enabled: false};
        return {
          device,
          shopCameraOn: policy.shopCameraOn(shopSnap.data() || {}),
        };
      });
    },
);

exports.syncCameraAccessOnDeviceDeleted = onDocumentDeleted(
    {document: "shops/{shopId}/devices/{deviceId}", region},
    async (event) => {
      const shopId = event.params.shopId;
      const deviceId = event.params.deviceId;
      const ids = await loadRequestIds(shopId, "deviceId", deviceId);
      await commitMany(shopId, ids, async () => {
        return {
          device: {id: deviceId, type: "camera", enabled: false},
          shopCameraOn: true,
        };
      });
    },
);

exports.syncCameraAccessOnShop = onDocumentUpdated(
    {document: "shops/{shopId}", region},
    async (event) => {
      if (!event.data) {
        return;
      }
      const beforeOn = policy.shopCameraOn(event.data.before.data() || {});
      const afterOn = policy.shopCameraOn(event.data.after.data() || {});
      if (beforeOn === afterOn || afterOn) {
        return;
      }
      const shopId = event.params.shopId;
      const snap = await admin.firestore()
          .collection("shops")
          .doc(shopId)
          .collection("camera_access_requests")
          .where("status", "in", [
            policy.STATUS_PENDING,
            policy.STATUS_NEEDS_INFO,
            policy.STATUS_INVITED,
            policy.STATUS_CONFIRMED,
          ])
          .get();
      const shopRef = admin.firestore().collection("shops").doc(shopId);
      await commitMany(
          shopId,
          snap.docs.map((doc) => doc.id),
          async (transaction) => {
            const live = await transaction.get(shopRef);
            return {
              shopCameraOn: policy.shopCameraOn(live.data() || {}),
            };
          },
      );
    },
);
