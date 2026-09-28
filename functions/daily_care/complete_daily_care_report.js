/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/complete_daily_care_report.js
// 功能說明：店家人員確認完成每日照護回報。用 Admin SDK 寫入完整內容，
// 避免客戶端直接寫 daily_care_records 被規則擋下。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  getShopMember,
  isRootAdmin,
  normalizeString,
  toInt,
} = require("../daycare/daycare_utils");
const {
  compactDateKey,
  expectedDailyCareRecordId,
  isDaycare,
} = require("./daily_care_expiry");
const {validateDailyCareSession} = require("./daily_care_entitlement");

const BLOCKED_STATUSES = new Set([
  "cancelled",
  "no_show",
  "rejected",
  "expired",
  "refused",
  "checked_out",
  "completed",
]);

function throwHttp(code, message) {
  throw new HttpsError(code, message);
}

function settlementLocked(booking) {
  if (!booking) {
    return true;
  }
  if (booking.settlementConfirmed === true) {
    return true;
  }
  if (booking.settledAt) {
    return true;
  }
  return typeof booking.finalSettlementAmount === "number" &&
    Number.isFinite(booking.finalSettlementAmount);
}

function canWriteBooking(booking) {
  const status = normalizeString(booking && booking.status);
  if (status !== "checked_in") {
    return false;
  }
  if (BLOCKED_STATUSES.has(status)) {
    return false;
  }
  return !settlementLocked(booking);
}

function plainValue(value) {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  return null;
}

function sanitizeMap(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return {};
  }
  const out = {};
  Object.keys(raw).forEach((key) => {
    const name = normalizeString(key);
    const value = plainValue(raw[key]);
    if (!name || value == null) {
      return;
    }
    if (typeof value === "string" && !value.trim()) {
      return;
    }
    out[name] = value;
  });
  return out;
}

function hasReportContent(values, petNotes) {
  if (Object.keys(values).length > 0) {
    return true;
  }
  return Object.keys(petNotes).length > 0;
}

async function assertStaff(shopId, uid) {
  if (isRootAdmin(uid)) {
    return;
  }
  const member = await getShopMember(shopId, uid);
  if (!member || member.active === false) {
    throwHttp("permission-denied", "沒有這家店的照護權限");
  }
}

async function countSessionPhotos(bookingId, recordId, dateKey, sessionIndex) {
  const snap = await admin.firestore()
      .collection("daily_care_photos")
      .where("bookingId", "==", bookingId)
      .get();
  let count = 0;
  snap.docs.forEach((doc) => {
    const data = doc.data() || {};
    if (!normalizeString(data.previewUrl) &&
      !normalizeString(data.previewStoragePath)) {
      return;
    }
    const storedId = normalizeString(data.dailyCareRecordId);
    if (storedId === recordId) {
      count += 1;
      return;
    }
    const sameSession = toInt(data.sessionIndex, -1) === sessionIndex;
    const photoKey = compactDateKey(data.recordDate);
    if (!storedId && sameSession && photoKey === dateKey) {
      count += 1;
    }
  });
  return count;
}

exports.completeDailyCareReport = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throwHttp("unauthenticated", "請先登入");
      }
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const roomId = normalizeString(data.roomId);
      const roomName = normalizeString(data.roomName);
      const sessionName = normalizeString(data.sessionName);
      const clientRecordId = normalizeString(data.dailyCareRecordId);
      const operatorName = normalizeString(data.operatorName);
      const sessionIndex = toInt(data.sessionIndex, 0);
      if (!shopId || !bookingId) {
        throwHttp("invalid-argument", "缺少店家或訂單");
      }
      if (sessionIndex < 0) {
        throwHttp("invalid-argument", "場次不正確");
      }

      const recordDate = data.recordDate;
      const dateKey = compactDateKey(recordDate);
      if (!/^\d{8}$/.test(dateKey)) {
        throwHttp("invalid-argument", "照護日期不正確");
      }
      const recordId = expectedDailyCareRecordId(
          bookingId,
          dateKey,
          sessionIndex,
      );
      if (clientRecordId && clientRecordId !== recordId) {
        throwHttp("invalid-argument", "照護紀錄編號不一致");
      }

      const values = sanitizeMap(data.values);
      const petNotes = sanitizeMap(data.petNotes);
      if (!hasReportContent(values, petNotes)) {
        throwHttp("failed-precondition", "回報內容沒有寫入，請再按一次確認完成");
      }

      await assertStaff(shopId, request.auth.uid);

      const bookingSnap = await admin.firestore()
          .collection("bookings")
          .doc(bookingId)
          .get();
      if (!bookingSnap.exists) {
        throwHttp("not-found", "找不到訂單");
      }
      const booking = bookingSnap.data() || {};
      if (normalizeString(booking.shopId) !== shopId) {
        throwHttp("permission-denied", "訂單不屬於這家店");
      }
      if (!canWriteBooking(booking)) {
        throwHttp("failed-precondition", "訂單已結清，回報已鎖定");
      }

      const daycare = isDaycare(booking);
      if (!daycare && !roomId) {
        throwHttp("invalid-argument", "缺少房間 ID");
      }

      const serviceDate =
        `${dateKey.slice(0, 4)}-${dateKey.slice(4, 6)}-${dateKey.slice(6, 8)}`;
      const careDecision = validateDailyCareSession(booking, {
        shopId,
        roomId,
        sessionIndex,
        recordDate: serviceDate,
      });
      if (!careDecision.ok) {
        throwHttp("failed-precondition", careDecision.message);
      }
      // 台灣日曆日 00:00。文件 ID 的 yyyyMMdd 與這個 Timestamp 必須是同一天。
      const recordAt = admin.firestore.Timestamp.fromDate(
          new Date(`${serviceDate}T00:00:00+08:00`),
      );
      const petIds = Array.isArray(data.petIds) ?
        data.petIds.map((id) => normalizeString(id)).filter(Boolean) :
        [];
      const requestedPhotoCount = Math.max(0, toInt(data.photoCount, 0));
      const storedPhotoCount = await countSessionPhotos(
          bookingSnap.id,
          recordId,
          dateKey,
          sessionIndex,
      );
      const photoCount = Math.max(requestedPhotoCount, storedPhotoCount);
      const serviceType =
        normalizeString(data.serviceType) === "daycare" || daycare ?
          "daycare" :
          "accommodation";

      const ref = admin.firestore()
          .collection("daily_care_records")
          .doc(recordId);
      await admin.firestore().runTransaction(async (tx) => {
        const existing = await tx.get(ref);
        const previous = existing.exists ? (existing.data() || {}) : {};
        const payload = {
          shopId,
          bookingId: bookingSnap.id,
          roomId,
          roomName,
          recordDate: recordAt,
          sessionIndex,
          recordIndex: sessionIndex,
          sessionName,
          serviceType,
          serviceDate,
          petIds,
          values,
          petNotes,
          photoCount,
          photosLocked: true,
          reportStatus: "completed",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (!normalizeString(previous.createdByUid)) {
          payload.createdByUid = request.auth.uid;
          payload.createdByName = operatorName;
        }
        if (!previous.createdAt) {
          payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
        }
        tx.set(ref, payload, {merge: true});
      });

      return {
        ok: true,
        recordId,
        serviceDate,
        photoCount,
        reportStatus: "completed",
      };
    },
);
