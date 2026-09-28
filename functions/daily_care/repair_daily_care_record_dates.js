/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/repair_daily_care_record_dates.js
// 功能說明：只校正「整段住宿回報日往前偏一天」的既有紀錄與照片 metadata。
// 不改 Storage 路徑、不刪照片、不處理安親。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  getShopMember,
  isRootAdmin,
  normalizeString,
  toDate,
  toInt,
} = require("../daycare/daycare_utils");
const {
  compactDateKey,
  expectedDailyCareRecordId,
  isDaycare,
} = require("./daily_care_expiry");

function throwHttp(code, message) {
  throw new HttpsError(code, message);
}

function skipped(reason) {
  return {
    repaired: false,
    oldRecordIds: [],
    newRecordIds: [],
    updatedPhotoCount: 0,
    skippedReason: reason,
  };
}

function addDays(key, delta) {
  const year = Number(String(key).slice(0, 4));
  const month = Number(String(key).slice(4, 6));
  const day = Number(String(key).slice(6, 8));
  const utc = new Date(Date.UTC(year, month - 1, day + delta));
  const mm = String(utc.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(utc.getUTCDate()).padStart(2, "0");
  return `${utc.getUTCFullYear()}${mm}${dd}`;
}

function slashKey(compact) {
  return `${compact.slice(0, 4)}/${compact.slice(4, 6)}/${compact.slice(6, 8)}`;
}

function isoDay(compact) {
  return `${compact.slice(0, 4)}-${compact.slice(4, 6)}-${compact.slice(6, 8)}`;
}

function taipeiMidnight(compact) {
  return admin.firestore.Timestamp.fromDate(
      new Date(`${isoDay(compact)}T00:00:00+08:00`),
  );
}

function compactServiceDate(raw) {
  const text = String(raw == null ? "" : raw).trim();
  const matched = text.match(/^(\d{4})[/-](\d{2})[/-](\d{2})/);
  if (matched) {
    return `${matched[1]}${matched[2]}${matched[3]}`;
  }
  const digits = text.replace(/\D/g, "");
  return digits.length >= 8 ? digits.slice(0, 8) : "";
}

function uniqueSorted(keys) {
  return [...new Set(keys.filter(Boolean))].sort();
}

function sameSet(left, right) {
  const a = uniqueSorted(left);
  const b = uniqueSorted(right);
  if (a.length !== b.length) {
    return false;
  }
  return a.every((value, index) => value === b[index]);
}

function stayBounds(booking) {
  const start = toDate(booking.startDate) ||
    toDate(booking.checkInAt) ||
    toDate(booking.checkInDate);
  const end = toDate(booking.endDate) ||
    toDate(booking.checkOutAt) ||
    toDate(booking.checkOutDate);
  return {start, end};
}

function legalStayKeys(booking) {
  const bounds = stayBounds(booking);
  if (!bounds.start || !bounds.end) {
    return [];
  }
  const startKey = compactDateKey(bounds.start);
  const endKey = compactDateKey(bounds.end);
  const keys = [];
  let cursor = startKey;
  while (cursor < endKey && keys.length < 400) {
    keys.push(cursor);
    cursor = addDays(cursor, 1);
  }
  return keys;
}

function serviceDateKeys(booking) {
  const entitlement = booking.dailyCareEntitlement;
  const raw = entitlement && Array.isArray(entitlement.serviceDates) ?
    entitlement.serviceDates : [];
  return uniqueSorted(raw.map(compactServiceDate));
}

function recordIdentity(docId, data) {
  const match = String(docId).match(/_(\d{8})_(\d+)$/);
  if (match) {
    return {
      dateKey: match[1],
      sessionIndex: Number(match[2]) || 0,
    };
  }
  const dateKey = data && data.recordDate ?
    compactDateKey(data.recordDate) :
    compactServiceDate(data && data.serviceDate);
  return {
    dateKey,
    sessionIndex: toInt(data && data.sessionIndex, 0),
  };
}

function contentScore(data) {
  if (!data) {
    return 0;
  }
  const values = data.values && typeof data.values === "object" &&
    !Array.isArray(data.values) ? Object.keys(data.values).length : 0;
  const notes = data.petNotes && typeof data.petNotes === "object" &&
    !Array.isArray(data.petNotes) ? Object.keys(data.petNotes).length : 0;
  let score = values + notes;
  if (normalizeString(data.reportStatus) === "completed") {
    score += 10;
  }
  if (data.photosLocked === true) {
    score += 3;
  }
  if (data.completedAt) {
    score += 2;
  }
  return score;
}

function mergeRecords(existing, incoming, target) {
  const hasExisting = !!(existing && Object.keys(existing).length);
  const incomingData = incoming || {};
  const existingData = hasExisting ? existing : null;
  const richer = !existingData ||
    contentScore(incomingData) > contentScore(existingData) ?
    incomingData : existingData;
  const other = richer === existingData ?
    incomingData : (existingData || {});
  const merged = {...other, ...richer};
  merged.shopId = target.shopId;
  merged.bookingId = target.bookingId;
  merged.recordDate = target.recordDate;
  merged.serviceDate = target.serviceDate;
  merged.sessionIndex = target.sessionIndex;
  merged.recordIndex = target.sessionIndex;
  merged.dailyCareRecordId = target.recordId;
  merged.values = richer.values || other.values || {};
  merged.petNotes = richer.petNotes || other.petNotes || {};
  merged.photoCount = Math.max(
      toInt(existingData && existingData.photoCount, 0),
      toInt(incomingData.photoCount, 0),
  );
  merged.photosLocked = (existingData && existingData.photosLocked === true) ||
    incomingData.photosLocked === true;
  merged.createdAt = (existingData && existingData.createdAt) ||
    incomingData.createdAt || null;
  merged.createdBy = (existingData && existingData.createdBy) ||
    incomingData.createdBy || null;
  merged.createdByUid = (existingData && existingData.createdByUid) ||
    incomingData.createdByUid || "";
  merged.createdByName = (existingData && existingData.createdByName) ||
    incomingData.createdByName || "";
  merged.completedAt = (existingData && existingData.completedAt) ||
    incomingData.completedAt || null;
  merged.updatedAt = richer.updatedAt || other.updatedAt || null;
  merged.reportStatus = richer.reportStatus || other.reportStatus || "";
  if (merged.createdAt == null) {
    delete merged.createdAt;
  }
  if (merged.createdBy == null) {
    delete merged.createdBy;
  }
  if (merged.completedAt == null) {
    delete merged.completedAt;
  }
  if (merged.updatedAt == null) {
    delete merged.updatedAt;
  }
  return merged;
}

/**
 * 只在整段早一天時回傳要搬的日期。不符合就 repair=false。
 * @param {{legalKeys: string[], serviceDateKeys: string[],
 *   recordDateKeys: string[]}} input
 * @return {Object}
 */
function planAccommodationDateRepair(input) {
  const legal = uniqueSorted(input.legalKeys || []);
  const expectedOld = legal.map((key) => addDays(key, -1));
  const service = uniqueSorted(input.serviceDateKeys || []);
  const records = uniqueSorted(input.recordDateKeys || []);
  const serviceShifted = service.length > 0 && sameSet(service, expectedOld);
  const recordsFullShift = records.length > 0 && sameSet(records, expectedOld);
  const recordsOnlyEarly = records.length > 0 && records.every((key) => {
    return expectedOld.includes(key) && !legal.includes(key);
  });
  if (!serviceShifted && !recordsFullShift && !recordsOnlyEarly) {
    return {repair: false, reason: "回報日期不是整段往前偏一天", moves: []};
  }
  let fromKeys = [];
  if (recordsFullShift) {
    fromKeys = records.filter((key) => expectedOld.includes(key));
  } else if (recordsOnlyEarly) {
    fromKeys = records;
  } else if (serviceShifted) {
    fromKeys = records.filter((key) => {
      return expectedOld.includes(key) && !legal.includes(key);
    });
  }
  const moves = [...fromKeys].sort().reverse().map((from) => ({
    from,
    to: addDays(from, 1),
  }));
  return {
    repair: moves.length > 0 || serviceShifted,
    reason: "",
    moves,
    legalKeys: legal,
    updateServiceDates: service.length > 0 && !sameSet(service, legal),
  };
}

function photoBelongs(data, oldId, fromKey, sessionIndex) {
  const bound = normalizeString(data.dailyCareRecordId);
  if (bound && bound === oldId) {
    return true;
  }
  const key = compactServiceDate(data.dateKey);
  const session = toInt(data.sessionIndex, 0);
  return key === fromKey && session === sessionIndex &&
    (!bound || bound === oldId);
}

async function loadBookingRecords(firestore, bookingId, fromKeys, perDay) {
  const found = new Map();
  const snap = await firestore.collection("daily_care_records")
      .where("bookingId", "==", bookingId)
      .get();
  snap.docs.forEach((doc) => {
    found.set(doc.id, doc);
  });
  const sessions = Math.max(1, Math.min(12, perDay));
  for (const key of fromKeys) {
    for (let index = 0; index < sessions; index++) {
      const id = expectedDailyCareRecordId(bookingId, key, index);
      if (found.has(id)) {
        continue;
      }
      const doc = await firestore.collection("daily_care_records").doc(id).get();
      if (doc.exists) {
        found.set(doc.id, doc);
      }
    }
  }
  return [...found.values()];
}

async function moveSession(firestore, move) {
  const oldRef = firestore.collection("daily_care_records").doc(move.oldId);
  const newRef = firestore.collection("daily_care_records").doc(move.newId);
  const photoSnap = await firestore.collection("daily_care_photos")
      .where("bookingId", "==", move.bookingId)
      .get();
  const downloadSnap = await firestore.collection("daily_care_photo_downloads")
      .where("bookingId", "==", move.bookingId)
      .get();
  const photos = photoSnap.docs.filter((doc) => {
    const data = doc.data() || {};
    if (normalizeString(data.dailyCareRecordId) === move.newId) {
      return false;
    }
    return photoBelongs(data, move.oldId, move.fromKey, move.sessionIndex);
  });
  const photoIds = new Set(photos.map((doc) => doc.id));
  const downloads = downloadSnap.docs.filter((doc) => {
    const data = doc.data() || {};
    if (normalizeString(data.dailyCareRecordId) === move.newId) {
      return false;
    }
    return photoIds.has(doc.id) ||
      photoIds.has(normalizeString(data.photoId)) ||
      normalizeString(data.dailyCareRecordId) === move.oldId;
  });
  const updatedPhotos = await firestore.runTransaction(async (tx) => {
    const oldSnap = await tx.get(oldRef);
    const newSnap = await tx.get(newRef);
    const photoReads = [];
    for (const doc of photos) {
      photoReads.push(await tx.get(doc.ref));
    }
    const downloadReads = [];
    for (const doc of downloads) {
      downloadReads.push(await tx.get(doc.ref));
    }
    const oldData = oldSnap.exists ? (oldSnap.data() || {}) : null;
    const newData = newSnap.exists ? (newSnap.data() || {}) : null;
    let updated = 0;
    if (!oldData && !newData && photoReads.length === 0) {
      return 0;
    }
    if (oldData || newData) {
      tx.set(newRef, mergeRecords(newData, oldData, {
        shopId: move.shopId,
        bookingId: move.bookingId,
        recordId: move.newId,
        recordDate: taipeiMidnight(move.toKey),
        serviceDate: isoDay(move.toKey),
        sessionIndex: move.sessionIndex,
      }));
    }
    const patch = {
      dailyCareRecordId: move.newId,
      recordDate: taipeiMidnight(move.toKey),
      serviceDate: isoDay(move.toKey),
      dateKey: move.toKey,
      sessionIndex: move.sessionIndex,
    };
    photoReads.forEach((snap) => {
      if (!snap.exists) {
        return;
      }
      tx.set(snap.ref, patch, {merge: true});
      updated += 1;
    });
    downloadReads.forEach((snap) => {
      if (!snap.exists) {
        return;
      }
      tx.set(snap.ref, {
        dailyCareRecordId: move.newId,
        recordDate: taipeiMidnight(move.toKey),
        serviceDate: isoDay(move.toKey),
        sessionIndex: move.sessionIndex,
      }, {merge: true});
    });
    if (oldSnap.exists && move.oldId !== move.newId) {
      tx.delete(oldRef);
    }
    return updated;
  });
  return updatedPhotos || 0;
}

async function repairAccommodationRecords(firestore, shopId, bookingId) {
  const bookingRef = firestore.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();
  if (!bookingSnap.exists) {
    throwHttp("not-found", "找不到訂單");
  }
  const booking = bookingSnap.data() || {};
  if (normalizeString(booking.shopId) !== shopId) {
    throwHttp("permission-denied", "訂單不屬於這家店");
  }
  if (isDaycare(booking)) {
    return skipped("不是住宿訂單");
  }
  const legal = legalStayKeys(booking);
  if (legal.length === 0) {
    return skipped("訂單沒有入住與退房日期");
  }
  const service = serviceDateKeys(booking);
  const expectedOld = legal.map((key) => addDays(key, -1));
  const entitlement = booking.dailyCareEntitlement || {};
  const perDay = Math.max(
      toInt(entitlement.finalReports, 0),
      Array.isArray(entitlement.sessionLabels) ?
        entitlement.sessionLabels.length : 0,
      1,
  );
  const recordDocs = await loadBookingRecords(
      firestore, bookingId, expectedOld, perDay,
  );
  const recordDateKeys = recordDocs.map((doc) => {
    return recordIdentity(doc.id, doc.data() || {}).dateKey;
  });
  const plan = planAccommodationDateRepair({
    legalKeys: legal,
    serviceDateKeys: service,
    recordDateKeys,
  });
  if (!plan.repair) {
    return skipped(plan.reason || "回報日期不是整段往前偏一天");
  }
  const moveByDate = new Map(plan.moves.map((move) => [move.from, move.to]));
  const sessions = [];
  recordDocs.forEach((doc) => {
    const identity = recordIdentity(doc.id, doc.data() || {});
    if (!moveByDate.has(identity.dateKey)) {
      return;
    }
    sessions.push({
      fromKey: identity.dateKey,
      toKey: moveByDate.get(identity.dateKey),
      sessionIndex: identity.sessionIndex,
      oldId: doc.id,
    });
  });
  sessions.sort((left, right) => {
    if (left.fromKey !== right.fromKey) {
      return right.fromKey.localeCompare(left.fromKey);
    }
    return right.sessionIndex - left.sessionIndex;
  });
  const oldRecordIds = [];
  const newRecordIds = [];
  let updatedPhotoCount = 0;
  for (const session of sessions) {
    const newId = expectedDailyCareRecordId(
        bookingId, session.toKey, session.sessionIndex,
    );
    if (session.oldId === newId) {
      continue;
    }
    updatedPhotoCount += await moveSession(firestore, {
      shopId,
      bookingId,
      oldId: session.oldId,
      newId,
      fromKey: session.fromKey,
      toKey: session.toKey,
      sessionIndex: session.sessionIndex,
    });
    oldRecordIds.push(session.oldId);
    newRecordIds.push(newId);
  }
  if (plan.updateServiceDates) {
    await bookingRef.set({
      dailyCareEntitlement: {
        ...entitlement,
        serviceDates: legal.map(slashKey),
      },
    }, {merge: true});
  }
  return {
    repaired: true,
    oldRecordIds,
    newRecordIds,
    updatedPhotoCount,
    skippedReason: "",
  };
}

async function assertRepairCaller(shopId, uid) {
  if (isRootAdmin(uid)) {
    return;
  }
  const member = await getShopMember(shopId, uid);
  const role = normalizeString(member && member.role);
  const allowed = role === "owner" || role === "manager" || role === "staff";
  if (member && member.active !== false && allowed) {
    return;
  }
  const shopSnap = await admin.firestore().collection("shops").doc(shopId).get();
  if (normalizeString(shopSnap.data() && shopSnap.data().ownerUid) === uid) {
    return;
  }
  throwHttp("permission-denied", "沒有這家店的回報校正權限");
}

const repairDailyCareRecordDates = onCall(
    {region: "asia-east1"},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throwHttp("unauthenticated", "請先登入");
      }
      const shopId = normalizeString(request.data && request.data.shopId);
      const bookingId = normalizeString(request.data && request.data.bookingId);
      if (!shopId || !bookingId) {
        throwHttp("invalid-argument", "缺少店家或訂單");
      }
      await assertRepairCaller(shopId, uid);
      return repairAccommodationRecords(
          admin.firestore(), shopId, bookingId,
      );
    },
);

module.exports = {
  repairDailyCareRecordDates,
  planAccommodationDateRepair,
  repairAccommodationRecords,
};
