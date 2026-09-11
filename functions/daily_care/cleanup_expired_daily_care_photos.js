/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/cleanup_expired_daily_care_photos.js
// 功能說明：每小時分批清除已到期照護照片；失敗／略過不永久擋住後續資料。

const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  isRootAdmin,
  normalizeString,
  toDate,
  toInt,
} = require("../daycare/daycare_utils");
const {
  bookingEnded,
  computeExpiresAt,
  stampExpiresForBooking,
  actualServiceEnd,
  evaluateCleanupDecision,
  nextRetryAt,
} = require("./daily_care_expiry");
const {
  deletePhotoFilesAndDocs,
  releaseReservation,
} = require("./daily_care_photo_ops");

const BATCH_SIZE = 40;
const MAX_BATCHES = 12;
const MAX_RUNTIME_MS = 45000;
const MAX_RESERVATION_BATCHES = 8;

function encodePageToken(token) {
  if (!token) {
    return "";
  }
  return Buffer.from(JSON.stringify(token), "utf8").toString("base64");
}

function decodePageToken(raw) {
  const text = String(raw || "").trim();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(Buffer.from(text, "base64").toString("utf8"));
  } catch (error) {
    return null;
  }
}

function isRetryHeld(data, now) {
  const retry = toDate(data && data.cleanupRetryAfter);
  return !!(retry && retry.getTime() > now.getTime());
}

async function markHold(ref, data, now, reason) {
  const failCount = toInt(data && data.cleanupFailCount, 0) + 1;
  await ref.set({
    cleanupFailCount: failCount,
    cleanupRetryAfter: admin.firestore.Timestamp.fromDate(
        nextRetryAt(now, failCount),
    ),
    cleanupHoldReason: reason || "",
    lastCleanupAttemptAt: admin.firestore.Timestamp.fromDate(now),
  }, {merge: true});
}

async function applyExpiry(firestore, photoId, photo, download, liveExpires) {
  const expiresTs = admin.firestore.Timestamp.fromDate(liveExpires);
  const batch = firestore.batch();
  batch.set(firestore.collection("daily_care_photos").doc(photoId), {
    expiresAt: expiresTs,
  }, {merge: true});
  batch.set(firestore.collection("daily_care_photo_downloads").doc(photoId), {
    shopId: (photo && photo.shopId) || (download && download.shopId) || "",
    bookingId: (photo && photo.bookingId) ||
      (download && download.bookingId) || "",
    photoId,
    expiresAt: expiresTs,
  }, {merge: true});
  await batch.commit();
}

async function clearExpiry(firestore, photoId) {
  const batch = firestore.batch();
  batch.set(firestore.collection("daily_care_photos").doc(photoId), {
    expiresAt: admin.firestore.FieldValue.delete(),
  }, {merge: true});
  batch.set(firestore.collection("daily_care_photo_downloads").doc(photoId), {
    expiresAt: admin.firestore.FieldValue.delete(),
  }, {merge: true});
  await batch.commit();
}

async function loadCleanupContext(firestore, downloadDoc) {
  const download = downloadDoc.data() || {};
  const bookingId = normalizeString(download.bookingId);
  const photoSnap = await firestore.collection("daily_care_photos")
      .doc(downloadDoc.id).get();
  const photo = photoSnap.exists ? (photoSnap.data() || {}) : {};
  let bookingExists = false;
  let booking = {};
  if (bookingId) {
    const bookingSnap = await firestore.collection("bookings")
        .doc(bookingId).get();
    bookingExists = bookingSnap.exists;
    booking = bookingSnap.exists ? (bookingSnap.data() || {}) : {};
  }
  return {
    download,
    photo,
    photoExists: photoSnap.exists,
    bookingExists,
    booking,
    bookingId,
  };
}

async function processExpiredDownload(firestore, downloadDoc, now) {
  const ref = downloadDoc.ref;
  const data = downloadDoc.data() || {};
  if (isRetryHeld(data, now)) {
    return {status: "held"};
  }
  const ctx = await loadCleanupContext(firestore, downloadDoc);
  const photoForCheck = ctx.photoExists ? ctx.photo : {
    shopId: ctx.download.shopId,
    bookingId: ctx.download.bookingId,
  };
  const decision = evaluateCleanupDecision({
    bookingExists: ctx.bookingExists,
    booking: ctx.booking,
    download: ctx.download,
    photo: photoForCheck,
    now,
  });
  if (decision.action === "hold") {
    await markHold(ref, data, now, decision.reason);
    return {status: "held", reason: decision.reason};
  }
  if (decision.action === "correct_expiry") {
    await applyExpiry(
        firestore,
        downloadDoc.id,
        ctx.photo,
        ctx.download,
        decision.liveExpires,
    );
    return {status: "corrected", reason: decision.reason};
  }
  if (decision.action === "clear_expiry") {
    await clearExpiry(firestore, downloadDoc.id);
    return {status: "cleared", reason: decision.reason};
  }
  const freshCtx = await loadCleanupContext(firestore, downloadDoc);
  const fresh = evaluateCleanupDecision({
    bookingExists: freshCtx.bookingExists,
    booking: freshCtx.booking,
    download: freshCtx.download,
    photo: freshCtx.photoExists ? freshCtx.photo : {
      shopId: freshCtx.download.shopId,
      bookingId: freshCtx.download.bookingId,
    },
    now,
  });
  if (fresh.action !== "delete") {
    if (fresh.action === "hold") {
      await markHold(ref, data, now, fresh.reason);
      return {status: "held", reason: fresh.reason};
    }
    if (fresh.action === "correct_expiry") {
      await applyExpiry(
          firestore,
          downloadDoc.id,
          freshCtx.photo,
          freshCtx.download,
          fresh.liveExpires,
      );
      return {status: "corrected", reason: fresh.reason};
    }
    if (fresh.action === "clear_expiry") {
      await clearExpiry(firestore, downloadDoc.id);
      return {status: "cleared", reason: fresh.reason};
    }
  }
  const photo = {
    ...freshCtx.photo,
    shopId: freshCtx.photo.shopId || freshCtx.download.shopId,
    bookingId: freshCtx.photo.bookingId || freshCtx.download.bookingId,
    downloadStoragePath: freshCtx.download.downloadStoragePath ||
      freshCtx.photo.downloadStoragePath,
  };
  try {
    await deletePhotoFilesAndDocs(firestore, downloadDoc.id, photo, true);
    return {status: "deleted"};
  } catch (error) {
    await markHold(ref, data, now, (error && error.message) || "刪除失敗");
    throw error;
  }
}

async function queryExpiredPage(firestore, collection, fieldFilters, cursorDoc,
    extraOrder) {
  let query = firestore.collection(collection);
  fieldFilters.forEach((item) => {
    query = query.where(item.field, item.op, item.value);
  });
  extraOrder.forEach((field) => {
    query = query.orderBy(field);
  });
  query = query.orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);
  if (cursorDoc) {
    query = query.startAfter(cursorDoc);
  }
  return query.get();
}

async function cleanupExpiredBatch(firestore, options) {
  const started = Date.now();
  const nowDate = options && options.now ? options.now : new Date();
  const now = admin.firestore.Timestamp.fromDate(nowDate);
  const maxBatches = (options && options.maxBatches) || MAX_BATCHES;
  const maxRuntimeMs = (options && options.maxRuntimeMs) || MAX_RUNTIME_MS;
  const stats = {
    scanned: 0,
    success: 0,
    failed: 0,
    skipped: 0,
    held: 0,
    corrected: 0,
    hasMore: false,
    reservationsScanned: 0,
    reservationsReleased: 0,
  };
  let cursor = null;
  let batches = 0;
  while (batches < maxBatches && (Date.now() - started) < maxRuntimeMs) {
    const snap = await queryExpiredPage(
        firestore,
        "daily_care_photo_downloads",
        [{field: "expiresAt", op: "<=", value: now}],
        cursor,
        ["expiresAt"],
    );
    batches += 1;
    if (snap.empty) {
      stats.hasMore = false;
      break;
    }
    stats.scanned += snap.size;
    for (let i = 0; i < snap.docs.length; i++) {
      const doc = snap.docs[i];
      try {
        const result = await processExpiredDownload(firestore, doc, nowDate);
        if (result.status === "deleted") {
          stats.success += 1;
        } else if (result.status === "held") {
          stats.held += 1;
          stats.skipped += 1;
        } else if (result.status === "corrected" ||
            result.status === "cleared") {
          stats.corrected += 1;
          stats.skipped += 1;
        } else {
          stats.skipped += 1;
        }
      } catch (error) {
        stats.failed += 1;
        console.error("cleanup daily care photo failed", doc.id, error);
      }
    }
    cursor = snap.docs[snap.docs.length - 1];
    if (snap.size < BATCH_SIZE) {
      stats.hasMore = false;
      break;
    }
    stats.hasMore = true;
  }
  let resCursor = null;
  let resBatches = 0;
  while (resBatches < MAX_RESERVATION_BATCHES &&
      (Date.now() - started) < maxRuntimeMs) {
    const staleRes = await queryExpiredPage(
        firestore,
        "daily_care_photo_reservations",
        [
          {field: "status", op: "==", value: "reserved"},
          {field: "expiresAt", op: "<=", value: now},
        ],
        resCursor,
        ["status", "expiresAt"],
    );
    resBatches += 1;
    if (staleRes.empty) {
      break;
    }
    stats.reservationsScanned += staleRes.size;
    for (let j = 0; j < staleRes.docs.length; j++) {
      const resDoc = staleRes.docs[j];
      const resData = resDoc.data() || {};
      if (isRetryHeld(resData, nowDate)) {
        stats.skipped += 1;
        continue;
      }
      try {
        await releaseReservation(firestore, resDoc.id, true);
        stats.reservationsReleased += 1;
        stats.success += 1;
      } catch (error) {
        stats.failed += 1;
        await markHold(
            resDoc.ref,
            resData,
            nowDate,
            (error && error.message) || "預留釋放失敗",
        );
        console.error("release reservation failed", resDoc.id, error);
      }
    }
    resCursor = staleRes.docs[staleRes.docs.length - 1];
    if (staleRes.size < BATCH_SIZE) {
      break;
    }
    stats.hasMore = true;
  }
  stats.pending = stats.hasMore;
  return stats;
}

function classifyInspectItem(ctx, now) {
  const previewExp = toDate(ctx.photo && ctx.photo.expiresAt);
  const downloadExp = toDate(ctx.download && ctx.download.expiresAt);
  const live = ctx.bookingExists ? computeExpiresAt(ctx.booking) : null;
  const issues = [];
  if (!ctx.bookingExists) {
    issues.push("找不到來源訂單");
  } else if (!actualServiceEnd(ctx.booking)) {
    issues.push("缺少可靠實際結束時間，無法補正期限");
  }
  if (previewExp && downloadExp &&
      previewExp.getTime() !== downloadExp.getTime()) {
    issues.push("preview 與 download 期限不一致");
  }
  if (ctx.bookingExists && bookingEnded(ctx.booking) && live) {
    if (!previewExp || !downloadExp) {
      issues.push("服務已結束但缺期限");
    }
  }
  const decision = evaluateCleanupDecision({
    bookingExists: ctx.bookingExists,
    booking: ctx.booking,
    download: ctx.download,
    photo: ctx.photo,
    now,
  });
  if (downloadExp && downloadExp.getTime() <= now.getTime()) {
    if (decision.action === "delete") {
      issues.push("已到期未清除");
    } else {
      issues.push(decision.reason);
    }
  }
  return {
    photoId: ctx.photoId,
    bookingId: ctx.bookingId,
    shopId: normalizeString(ctx.download.shopId || ctx.photo.shopId),
    issues,
    canStamp: !!(ctx.bookingExists && actualServiceEnd(ctx.booking) &&
      bookingEnded(ctx.booking) && (!previewExp || !downloadExp)),
    canDelete: decision.action === "delete",
  };
}

async function inspectExpiredPage(firestore, pageSize, pageToken, now) {
  const decoded = decodePageToken(pageToken);
  let query = firestore.collection("daily_care_photo_downloads")
      .where("expiresAt", "<=", admin.firestore.Timestamp.fromDate(now))
      .orderBy("expiresAt")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
  if (decoded && decoded.expiresAt && decoded.id) {
    query = query.startAfter(
        admin.firestore.Timestamp.fromDate(new Date(decoded.expiresAt)),
        decoded.id,
    );
  }
  const snap = await query.get();
  const items = [];
  for (let i = 0; i < snap.docs.length; i++) {
    const doc = snap.docs[i];
    const ctx = await loadCleanupContext(firestore, doc);
    ctx.photoId = doc.id;
    items.push(classifyInspectItem(ctx, now));
  }
  const last = snap.docs[snap.docs.length - 1];
  const lastData = last ? (last.data() || {}) : {};
  const hasMore = snap.size >= pageSize;
  return {
    pageCount: snap.size,
    hasMore,
    nextPageToken: hasMore && last ? encodePageToken({
      expiresAt: toDate(lastData.expiresAt) ?
        toDate(lastData.expiresAt).toISOString() : "",
      id: last.id,
    }) : "",
    items,
  };
}

exports.cleanupExpiredDailyCarePhotos = onSchedule(
    {
      schedule: "0 * * * *",
      timeZone: "Asia/Taipei",
      region: "asia-east1",
    },
    async () => {
      const result = await cleanupExpiredBatch(admin.firestore());
      console.log("cleanupExpiredDailyCarePhotos", result);
      return result;
    },
);

exports.stampDailyCarePhotoExpiryOnBooking = onDocumentUpdated(
    {
      document: "bookings/{bookingId}",
      region: "asia-east1",
    },
    async (event) => {
      const after = event.data && event.data.after && event.data.after.data();
      if (!after) {
        return;
      }
      const before = event.data.before && event.data.before.data() || {};
      const endAfter = actualServiceEnd(after);
      const endBefore = actualServiceEnd(before);
      if (!endAfter) {
        return;
      }
      if (endBefore && endBefore.getTime() === endAfter.getTime() &&
          normalizeString(before.status) === normalizeString(after.status)) {
        return;
      }
      await stampExpiresForBooking(
          admin.firestore(),
          event.params.bookingId,
          after,
      );
    },
);

exports.inspectDailyCarePhotos = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      if (!isRootAdmin(request.auth.uid)) {
        throw new HttpsError("permission-denied", "僅平台管理員可執行維護檢查");
      }
      const data = request.data || {};
      const dryRun = data.dryRun !== false;
      const executeAction = String(data.executeAction || "").trim();
      const execute = data.execute === true && dryRun === false;
      const firestore = admin.firestore();
      const now = new Date();
      const pageSize = Math.min(80, Math.max(10, toInt(data.pageSize, 40)));
      if (execute && executeAction === "cleanup") {
        return {
          dryRun: false,
          cleanup: await cleanupExpiredBatch(firestore),
          note: "已明確選擇執行清理；會刪除通過驗證的到期照片檔案與 metadata。",
        };
      }
      if (execute && executeAction === "stamp") {
        const bookingIds = Array.isArray(data.bookingIds) ?
          data.bookingIds : [];
        const stamped = [];
        for (let i = 0; i < bookingIds.length; i++) {
          const bookingId = normalizeString(bookingIds[i]);
          if (!bookingId) {
            continue;
          }
          const snap = await firestore.collection("bookings").doc(bookingId)
              .get();
          if (!snap.exists) {
            stamped.push({bookingId, ok: false, reason: "訂單不存在"});
            continue;
          }
          const booking = snap.data() || {};
          if (!actualServiceEnd(booking)) {
            stamped.push({
              bookingId,
              ok: false,
              reason: "無法確認實際結束時間，不猜測日期",
            });
            continue;
          }
          const result = await stampExpiresForBooking(
              firestore,
              bookingId,
              booking,
          );
          stamped.push({bookingId, ok: true, ...result});
        }
        return {
          dryRun: false,
          stamped,
          note: "僅對明確指定且可確認結束時間的訂單補正期限。",
        };
      }
      const page = await inspectExpiredPage(
          firestore,
          pageSize,
          data.pageToken,
          now,
      );
      return {
        dryRun: true,
        pageSize,
        pageCount: page.pageCount,
        hasMore: page.hasMore,
        nextPageToken: page.nextPageToken,
        items: page.items,
        note: "本頁筆數不是全量數量。dry-run 不會寫入、補正或刪檔。" +
          "到期後顧客存取會先被 Rules 拒絕；檔案需另外明確執行 cleanup。",
      };
    },
);

exports.cleanupExpiredBatch = cleanupExpiredBatch;
exports.processExpiredDownload = processExpiredDownload;
exports.inspectExpiredPage = inspectExpiredPage;
exports.BATCH_SIZE = BATCH_SIZE;
exports.MAX_BATCHES = MAX_BATCHES;
