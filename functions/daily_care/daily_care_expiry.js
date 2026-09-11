/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/daily_care_expiry.js
// 功能說明：以實際退房／安親結束時間起算 24 小時，不因補退款重設。

const admin = require("firebase-admin");
const {normalizeString, toDate} = require("../daycare/daycare_utils");

const RETENTION_MS = 24 * 60 * 60 * 1000;
const STAMP_CHUNK = 40;
const HOLD_MS_BASE = 15 * 60 * 1000;
const HOLD_MS_MAX = 6 * 60 * 60 * 1000;

function isDaycare(booking) {
  return normalizeString(booking.bookingKind) === "daycare" ||
    normalizeString(booking.serviceType) === "daycare";
}

function actualServiceEnd(booking) {
  if (isDaycare(booking)) {
    return toDate(booking.actualEndAt) ||
      toDate(booking.checkedOutAt) ||
      toDate(booking.completedAt);
  }
  return toDate(booking.checkOutAt) ||
    toDate(booking.checkedOutAt) ||
    toDate(booking.completedAt);
}

function computeExpiresAt(booking) {
  const end = actualServiceEnd(booking);
  if (!end) {
    return null;
  }
  return new Date(end.getTime() + RETENTION_MS);
}

function bookingEnded(booking) {
  if (normalizeString(booking.status) === "cancelled") {
    return false;
  }
  return actualServiceEnd(booking) != null &&
    (normalizeString(booking.status) === "completed" ||
      actualServiceEnd(booking).getTime() <= Date.now());
}

function sameTime(a, b) {
  const da = toDate(a);
  const db = toDate(b);
  if (!da || !db) {
    return false;
  }
  return da.getTime() === db.getTime();
}

function nextRetryAt(now, failCount) {
  const n = Math.max(0, Number(failCount) || 0);
  const ms = Math.min(HOLD_MS_MAX, HOLD_MS_BASE * Math.pow(2, n));
  return new Date(now.getTime() + ms);
}

function evaluateCleanupDecision({
  bookingExists,
  booking,
  download,
  photo,
  now,
}) {
  const nowMs = (now || new Date()).getTime();
  const shopId = normalizeString(download && download.shopId);
  const bookingId = normalizeString(download && download.bookingId);
  if (!shopId || !bookingId) {
    return {action: "hold", reason: "來源不明：缺少 shopId 或 bookingId"};
  }
  const photoShop = normalizeString(photo && photo.shopId);
  const photoBooking = normalizeString(photo && photo.bookingId);
  if (photoShop && photoShop !== shopId) {
    return {action: "hold", reason: "照片與下載 metadata 的 shopId 不一致"};
  }
  if (photoBooking && photoBooking !== bookingId) {
    return {action: "hold", reason: "照片與下載 metadata 的訂單不一致"};
  }
  if (!bookingExists) {
    return {action: "hold", reason: "找不到來源訂單，列入待處理"};
  }
  const bookingShop = normalizeString(booking && booking.shopId);
  if (bookingShop && bookingShop !== shopId) {
    return {action: "hold", reason: "訂單 shopId 與照片不符"};
  }
  if (!bookingEnded(booking || {})) {
    const live = computeExpiresAt(booking || {});
    if (live && live.getTime() > nowMs) {
      return {
        action: "correct_expiry",
        reason: "服務已恢復或期限已更正，有效期限尚未到期",
        liveExpires: live,
      };
    }
    return {
      action: "clear_expiry",
      reason: "服務尚未結束或已延住／恢復，不沿用失效期限",
    };
  }
  const liveExpires = computeExpiresAt(booking || {});
  if (!liveExpires) {
    return {action: "hold", reason: "缺少可靠實際結束時間，無法計算有效期限"};
  }
  if (liveExpires.getTime() > nowMs) {
    return {
      action: "correct_expiry",
      reason: "有效期限尚未到期，不得因舊 metadata 刪除",
      liveExpires,
    };
  }
  return {
    action: "delete",
    reason: "來源訂單存在、服務已結束且有效期限已到",
    liveExpires,
  };
}

function planStampWrites(photoData, downloadData, desired) {
  const desiredMs = desired.getTime();
  const preview = toDate(photoData && photoData.expiresAt);
  const download = toDate(downloadData && downloadData.expiresAt);
  if (preview && download && preview.getTime() === download.getTime()) {
    if (preview.getTime() === desiredMs) {
      return {updatePhoto: false, updateDownload: false, skipped: true};
    }
    return {updatePhoto: true, updateDownload: true, skipped: false};
  }
  return {
    updatePhoto: !preview || preview.getTime() !== desiredMs,
    updateDownload: !download || download.getTime() !== desiredMs,
    skipped: false,
    fillMissingDownload: !download && !!preview,
  };
}

async function stampExpiresForBooking(firestore, bookingId, booking) {
  if (!bookingEnded(booking || {})) {
    return {updated: 0, skipped: 0, aligned: 0};
  }
  const expires = computeExpiresAt(booking || {});
  if (!expires) {
    return {updated: 0, skipped: 0, aligned: 0};
  }
  const expiresTs = admin.firestore.Timestamp.fromDate(expires);
  const photos = await firestore.collection("daily_care_photos")
      .where("bookingId", "==", bookingId)
      .get();
  let updated = 0;
  let skipped = 0;
  let aligned = 0;
  const docs = photos.docs || [];
  for (let i = 0; i < docs.length; i += STAMP_CHUNK) {
    const chunk = docs.slice(i, i + STAMP_CHUNK);
    const batch = firestore.batch();
    let ops = 0;
    for (let j = 0; j < chunk.length; j++) {
      const doc = chunk[j];
      const photo = doc.data() || {};
      const downloadRef = firestore.collection("daily_care_photo_downloads")
          .doc(doc.id);
      const downloadSnap = await downloadRef.get();
      const download = downloadSnap.exists ? (downloadSnap.data() || {}) : {};
      const plan = planStampWrites(photo, download, expires);
      if (plan.skipped) {
        skipped += 1;
        continue;
      }
      if (plan.updatePhoto) {
        batch.set(doc.ref, {expiresAt: expiresTs}, {merge: true});
        ops += 1;
      }
      if (plan.updateDownload) {
        batch.set(downloadRef, {
          shopId: photo.shopId || download.shopId || "",
          bookingId: bookingId,
          photoId: doc.id,
          downloadStoragePath: download.downloadStoragePath ||
            photo.downloadStoragePath || "",
          expiresAt: expiresTs,
        }, {merge: true});
        ops += 1;
        if (plan.fillMissingDownload) {
          aligned += 1;
        }
      }
      if (plan.updatePhoto || plan.updateDownload) {
        updated += 1;
      } else {
        skipped += 1;
      }
    }
    if (ops > 0) {
      await batch.commit();
    }
  }
  return {updated, skipped, aligned};
}

function compactDateKey(recordDate) {
  const date = toDate(recordDate) || new Date();
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

function assertStoragePath(path, shopId, bookingId, photoId) {
  const text = String(path || "").trim();
  const prefix = `daily_care_photos/${shopId}/${bookingId}/`;
  if (!text.startsWith(prefix)) {
    throw new Error("照片路徑不屬於此訂單");
  }
  if (text.indexOf("/" + photoId + "/") < 0 &&
      text.indexOf("/" + photoId) < 0) {
    throw new Error("照片路徑與照片 ID 不符");
  }
  return text;
}

module.exports = {
  RETENTION_MS,
  STAMP_CHUNK,
  isDaycare,
  actualServiceEnd,
  computeExpiresAt,
  bookingEnded,
  sameTime,
  nextRetryAt,
  evaluateCleanupDecision,
  planStampWrites,
  stampExpiresForBooking,
  compactDateKey,
  assertStoragePath,
};
