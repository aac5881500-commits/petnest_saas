/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/daily_care_photo_ops.js
// 功能說明：照護照片原子預留、完成確認、釋放與刪除計數。

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
  PLATFORM_MAX_PHOTOS,
  PHOTOS_PER_SESSION,
  PHOTO_RULE_V2,
  photoRuleVersion,
  entitlementSessionCount,
} = require("./daily_care_entitlement");
const {
  bookingEnded,
  compactDateKey,
  expectedDailyCareRecordId,
  nextRecordPhotoCount,
  computeExpiresAt,
  isDaycare,
  stampExpiresForBooking,
  assertStoragePath,
} = require("./daily_care_expiry");

const RESERVE_TTL_MS = 10 * 60 * 1000;

function throwHttp(code, message) {
  throw new HttpsError(code, message);
}

async function assertStaff(shopId, uid) {
  if (isRootAdmin(uid)) {
    return;
  }
  const member = await getShopMember(shopId, uid);
  if (!member) {
    throwHttp("permission-denied", "沒有上傳照護照片的權限");
  }
}

function canWriteBooking(booking) {
  const status = normalizeString(booking.status);
  if (status === "cancelled") {
    return false;
  }
  if (isDaycare(booking)) {
    return true;
  }
  return status === "checked_in";
}

function entitlementPhotos(booking) {
  const snap = booking.dailyCareEntitlement || {};
  const photos = toInt(snap.finalPhotos, 0);
  if (photos > 0) {
    return Math.min(PLATFORM_MAX_PHOTOS, photos);
  }
  if (snap.enabled === false) {
    return 0;
  }
  return PLATFORM_MAX_PHOTOS;
}

function usageRef(firestore, bookingId, dateKey) {
  return firestore.collection("daily_care_photo_usage")
      .doc(`${bookingId}__${dateKey}`);
}

function sessionUsageRef(firestore, bookingId, dateKey, sessionIndex) {
  return firestore.collection("daily_care_photo_usage")
      .doc(`${bookingId}__${dateKey}__${sessionIndex}`);
}

function capacityRef(firestore, shopId, roomId, dateKey) {
  return firestore.collection("daily_care_photo_capacity")
      .doc(`${shopId}__${roomId}__${dateKey}`);
}

function resolvePhotoRecordId(photo) {
  const bound = normalizeString(photo && photo.dailyCareRecordId);
  if (bound) {
    return bound;
  }
  const dateKey = normalizeString(photo && photo.dateKey) ||
    compactDateKey(photo && photo.recordDate);
  return expectedDailyCareRecordId(
      photo && photo.bookingId, dateKey, toInt(photo && photo.sessionIndex, 0),
  );
}

function isV2(booking) {
  return photoRuleVersion(booking) >= PHOTO_RULE_V2;
}

function storageBasePath(shopId, bookingId, roomId, dateKey, sessionIndex,
    photoId) {
  return "daily_care_photos/" + shopId + "/" + bookingId + "/" + roomId +
    "/" + dateKey + "/" + sessionIndex + "/" + photoId;
}

exports.reserveDailyCarePhoto = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throwHttp("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const roomId = normalizeString(data.roomId);
      const sessionIndex = toInt(data.sessionIndex, 0);
      const recordDate = toDate(data.recordDate) || new Date();
      const clientRecordId = normalizeString(data.dailyCareRecordId);
      if (!shopId || !bookingId || !roomId) {
        throwHttp("invalid-argument", "缺少照片上傳資料");
      }
      if (!clientRecordId) {
        throwHttp("invalid-argument", "缺少照護紀錄 ID");
      }
      await assertStaff(shopId, uid);
      const firestore = admin.firestore();
      const bookingSnap = await firestore.collection("bookings")
          .doc(bookingId).get();
      if (!bookingSnap.exists) {
        throwHttp("not-found", "找不到訂單");
      }
      const booking = bookingSnap.data() || {};
      if (normalizeString(booking.shopId) !== shopId) {
        throwHttp("permission-denied", "訂單店家不一致");
      }
      if (!canWriteBooking(booking)) {
        throwHttp("failed-precondition", "目前狀態不可上傳照護照片");
      }
      const dateKey = compactDateKey(recordDate);
      const expectedRecordId = expectedDailyCareRecordId(
          bookingId, dateKey, sessionIndex,
      );
      if (clientRecordId !== expectedRecordId) {
        throwHttp("invalid-argument", "照護紀錄 ID 與日期場次不符");
      }
      const sessions = entitlementSessionCount(booking);
      if (sessionIndex < 0 || sessionIndex >= sessions) {
        throwHttp("failed-precondition", "此場次不在訂單照護權益內");
      }
      const recSnap = await firestore.collection("daily_care_records")
          .doc(expectedRecordId).get();
      if (recSnap.exists && recSnap.data().photosLocked === true) {
        throwHttp("failed-precondition", "此場照片已鎖定，不可追加或更換");
      }
      const v2 = isV2(booking);
      const quota = v2 ? PHOTOS_PER_SESSION : entitlementPhotos(booking);
      const reservationId = firestore
          .collection("daily_care_photo_reservations")
          .doc().id;
      const photoId = reservationId;
      const now = Date.now();
      const expiresAt = admin.firestore.Timestamp.fromDate(
          new Date(now + RESERVE_TTL_MS),
      );
      await firestore.runTransaction(async (tx) => {
        if (v2) {
          const sRef = sessionUsageRef(
              firestore, bookingId, dateKey, sessionIndex,
          );
          const sSnap = await tx.get(sRef);
          const used = toInt(sSnap.data() && sSnap.data().used, 0);
          const reserved = toInt(sSnap.data() && sSnap.data().reserved, 0);
          if (used + reserved + 1 > PHOTOS_PER_SESSION) {
            throwHttp("failed-precondition",
                "此場照片已達上限 " + PHOTOS_PER_SESSION + " 張");
          }
          tx.set(sRef, {
            shopId,
            bookingId,
            dateKey,
            sessionIndex,
            used,
            reserved: reserved + 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        } else {
          const uRef = usageRef(firestore, bookingId, dateKey);
          const cRef = capacityRef(firestore, shopId, roomId, dateKey);
          const uSnap = await tx.get(uRef);
          const cSnap = await tx.get(cRef);
          const usedBooking = toInt(uSnap.data() && uSnap.data().used, 0);
          const reservedBooking = toInt(
              uSnap.data() && uSnap.data().reserved, 0,
          );
          const usedRoom = toInt(cSnap.data() && cSnap.data().used, 0);
          const reservedRoom = toInt(cSnap.data() && cSnap.data().reserved, 0);
          if (usedBooking + reservedBooking + 1 > quota) {
            throwHttp("failed-precondition",
                "此訂單今日照片已達可提供張數 " + quota + " 張");
          }
          if (usedRoom + reservedRoom + 1 > PLATFORM_MAX_PHOTOS) {
            throwHttp("failed-precondition",
                "此房今日照片已達平台上限 " + PLATFORM_MAX_PHOTOS + " 張");
          }
          tx.set(uRef, {
            shopId,
            bookingId,
            dateKey,
            used: usedBooking,
            reserved: reservedBooking + 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          tx.set(cRef, {
            shopId,
            roomId,
            dateKey,
            used: usedRoom,
            reserved: reservedRoom + 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        tx.set(firestore.collection("daily_care_photo_reservations")
            .doc(reservationId), {
          shopId,
          bookingId,
          roomId,
          dateKey,
          sessionIndex,
          dailyCareRecordId: expectedRecordId,
          photoId,
          photoRuleVersion: v2 ? PHOTO_RULE_V2 : 1,
          status: "reserved",
          createdBy: uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt,
        });
      });
      return {
        ok: true,
        reservationId,
        photoId,
        dateKey,
        storageBasePath: storageBasePath(
            shopId, bookingId, roomId, dateKey, sessionIndex, photoId,
        ),
      };
    },
);

exports.completeDailyCarePhotoUpload = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throwHttp("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const reservationId = normalizeString(data.reservationId);
      const previewStoragePath = normalizeString(data.previewStoragePath);
      const downloadStoragePath = normalizeString(data.downloadStoragePath);
      const previewUrl = normalizeString(data.previewUrl);
      const roomName = normalizeString(data.roomName);
      const sessionName = normalizeString(data.sessionName);
      const previewBytes = toInt(data.previewBytes, 0);
      const downloadBytes = toInt(data.downloadBytes, 0);
      if (!reservationId || !previewStoragePath || !downloadStoragePath) {
        throwHttp("invalid-argument", "缺少完成上傳資料");
      }
      const firestore = admin.firestore();
      const resRef = firestore.collection("daily_care_photo_reservations")
          .doc(reservationId);
      const resSnap = await resRef.get();
      if (!resSnap.exists) {
        throwHttp("not-found", "找不到照片預留");
      }
      const reservation = resSnap.data() || {};
      await assertStaff(reservation.shopId, uid);
      if (normalizeString(reservation.status) === "completed") {
        return {ok: true, photoId: reservation.photoId, duplicate: true};
      }
      if (normalizeString(reservation.status) !== "reserved") {
        throwHttp("failed-precondition", "此預留已失效，請重新上傳");
      }
      const expires = toDate(reservation.expiresAt);
      if (expires && expires.getTime() < Date.now()) {
        throwHttp("deadline-exceeded", "預留已逾時，請重新上傳");
      }
      const shopId = reservation.shopId;
      const bookingId = reservation.bookingId;
      const roomId = reservation.roomId;
      const photoId = reservation.photoId;
      assertStoragePath(previewStoragePath, shopId, bookingId, photoId);
      assertStoragePath(downloadStoragePath, shopId, bookingId, photoId);
      const bucket = admin.storage().bucket();
      const previewFile = bucket.file(previewStoragePath);
      const downloadFile = bucket.file(downloadStoragePath);
      const previewExists = await previewFile.exists();
      const downloadExists = await downloadFile.exists();
      if (!previewExists[0] || !downloadExists[0]) {
        throwHttp("failed-precondition", "照片檔案尚未上傳完成");
      }
      const bookingSnap = await firestore.collection("bookings")
          .doc(bookingId).get();
      const booking = bookingSnap.data() || {};
      let expiresAt = computeExpiresAt(booking);
      if (!bookingEnded(booking)) {
        expiresAt = null;
      }
      const year = Number(String(reservation.dateKey).slice(0, 4));
      const month = Number(String(reservation.dateKey).slice(4, 6));
      const day = Number(String(reservation.dateKey).slice(6, 8));
      const recordDate = new Date(Date.UTC(year, month - 1, day));
      await firestore.runTransaction(async (tx) => {
        const fresh = await tx.get(resRef);
        const freshData = fresh.data() || {};
        if (normalizeString(freshData.status) === "completed") {
          return;
        }
        const sessionIndex = toInt(reservation.sessionIndex, 0);
        const dailyCareRecordId =
          normalizeString(reservation.dailyCareRecordId) ||
          expectedDailyCareRecordId(
              bookingId, reservation.dateKey, sessionIndex,
          );
        const recRef = firestore.collection("daily_care_records")
            .doc(dailyCareRecordId);
        const recSnap = await tx.get(recRef);
        const v2 = toInt(reservation.photoRuleVersion, 1) >= PHOTO_RULE_V2 ||
          isV2(booking);
        if (v2) {
          const sRef = sessionUsageRef(
              firestore, bookingId, reservation.dateKey, sessionIndex,
          );
          const sSnap = await tx.get(sRef);
          tx.set(sRef, {
            used: toInt(sSnap.data() && sSnap.data().used, 0) + 1,
            reserved: Math.max(0,
                toInt(sSnap.data() && sSnap.data().reserved, 0) - 1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        } else {
          const uRef = usageRef(firestore, bookingId, reservation.dateKey);
          const cRef = capacityRef(firestore, shopId, roomId,
              reservation.dateKey);
          const uSnap = await tx.get(uRef);
          const cSnap = await tx.get(cRef);
          tx.set(uRef, {
            used: toInt(uSnap.data() && uSnap.data().used, 0) + 1,
            reserved: Math.max(0,
                toInt(uSnap.data() && uSnap.data().reserved, 0) - 1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          tx.set(cRef, {
            used: toInt(cSnap.data() && cSnap.data().used, 0) + 1,
            reserved: Math.max(0,
                toInt(cSnap.data() && cSnap.data().reserved, 0) - 1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        tx.set(firestore.collection("daily_care_photos").doc(photoId), {
          shopId,
          bookingId,
          bookingKind: isDaycare(booking) ? "daycare" : "accommodation",
          roomId,
          roomName,
          recordDate: admin.firestore.Timestamp.fromDate(recordDate),
          dateKey: reservation.dateKey,
          dailyCareRecordId,
          sessionIndex: toInt(reservation.sessionIndex, 0),
          sessionName,
          previewUrl,
          previewStoragePath,
          downloadStoragePath,
          previewBytes,
          uploadedByUid: uid,
          published: false,
          expiresAt: expiresAt ?
            admin.firestore.Timestamp.fromDate(expiresAt) : null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.set(
            firestore.collection("daily_care_photo_downloads").doc(photoId),
            {
              shopId,
              bookingId,
              photoId,
              downloadStoragePath,
              downloadBytes,
              published: false,
              expiresAt: expiresAt ?
                admin.firestore.Timestamp.fromDate(expiresAt) : null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        );
        tx.set(recRef, {
          photoCount: nextRecordPhotoCount(
              recSnap.data() && recSnap.data().photoCount, 1,
          ),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        tx.update(resRef, {
          status: "completed",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      const freshSnap = await firestore.collection("bookings")
          .doc(bookingId).get();
      const freshBooking = freshSnap.data() || {};
      if (bookingEnded(freshBooking)) {
        await stampExpiresForBooking(firestore, bookingId, freshBooking);
      }
      const liveExpires = computeExpiresAt(freshBooking);
      return {
        ok: true,
        photoId,
        expiresAt: bookingEnded(freshBooking) && liveExpires ?
          liveExpires.toISOString() : null,
      };
    },
);

exports.releaseDailyCarePhotoReservation = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throwHttp("unauthenticated", "請先登入");
      }
      const reservationId = normalizeString(
          (request.data || {}).reservationId,
      );
      if (!reservationId) {
        throwHttp("invalid-argument", "缺少預留 ID");
      }
      const firestore = admin.firestore();
      await releaseReservation(firestore, reservationId, true);
      return {ok: true};
    },
);

exports.deleteDailyCarePhoto = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throwHttp("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const photoId = normalizeString((request.data || {}).photoId);
      if (!photoId) {
        throwHttp("invalid-argument", "缺少照片 ID");
      }
      const firestore = admin.firestore();
      const photoSnap = await firestore.collection("daily_care_photos")
          .doc(photoId).get();
      if (!photoSnap.exists) {
        return {ok: true, missing: true};
      }
      const photo = photoSnap.data() || {};
      await assertStaff(photo.shopId, uid);
      const recId = resolvePhotoRecordId(photo);
      const recSnap = await firestore.collection("daily_care_records")
          .doc(recId).get();
      const locked = recSnap.exists && recSnap.data().photosLocked === true;
      const reason = normalizeString((request.data || {}).reason);
      if (locked) {
        if (!reason) {
          throwHttp("failed-precondition", "照片已鎖定，撤下時請填寫原因");
        }
        await firestore.collection("daily_care_photo_actions").doc().set({
          shopId: photo.shopId,
          bookingId: photo.bookingId,
          photoId,
          action: "retract",
          reason,
          operatorUid: uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await deletePhotoFilesAndDocs(firestore, photoId, photo, !locked);
      return {ok: true};
    },
);

async function releaseReservation(firestore, reservationId, deleteFiles) {
  const resRef = firestore.collection("daily_care_photo_reservations")
      .doc(reservationId);
  const snap = await resRef.get();
  if (!snap.exists) {
    return;
  }
  const reservation = snap.data() || {};
  if (normalizeString(reservation.status) !== "reserved") {
    return;
  }
  await firestore.runTransaction(async (tx) => {
    const fresh = await tx.get(resRef);
    const data = fresh.data() || {};
    if (normalizeString(data.status) !== "reserved") {
      return;
    }
    const v2 = toInt(data.photoRuleVersion, 1) >= PHOTO_RULE_V2;
    if (v2) {
      const sRef = sessionUsageRef(
          firestore, data.bookingId, data.dateKey,
          toInt(data.sessionIndex, 0),
      );
      const sSnap = await tx.get(sRef);
      tx.set(sRef, {
        reserved: Math.max(0,
            toInt(sSnap.data() && sSnap.data().reserved, 0) - 1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    } else {
      const uRef = usageRef(firestore, data.bookingId, data.dateKey);
      const cRef = capacityRef(
          firestore, data.shopId, data.roomId, data.dateKey,
      );
      const uSnap = await tx.get(uRef);
      const cSnap = await tx.get(cRef);
      tx.set(uRef, {
        reserved: Math.max(0,
            toInt(uSnap.data() && uSnap.data().reserved, 0) - 1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      tx.set(cRef, {
        reserved: Math.max(0,
            toInt(cSnap.data() && cSnap.data().reserved, 0) - 1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    tx.update(resRef, {status: "released"});
  });
  if (deleteFiles) {
    const base = storageBasePath(
        reservation.shopId,
        reservation.bookingId,
        reservation.roomId,
        reservation.dateKey,
        toInt(reservation.sessionIndex, 0),
        reservation.photoId,
    );
    await safeDeleteFile(base + "/preview.jpg");
    await safeDeleteFile(base + "/download.jpg");
  }
}

async function deletePhotoFilesAndDocs(firestore, photoId, photo, adjustCount) {
  const previewPath = normalizeString(photo.previewStoragePath);
  let downloadPath = "";
  const dlSnap = await firestore.collection("daily_care_photo_downloads")
      .doc(photoId).get();
  if (dlSnap.exists) {
    downloadPath = normalizeString(dlSnap.data().downloadStoragePath);
  }
  if (!downloadPath) {
    downloadPath = normalizeString(photo.downloadStoragePath);
  }
  if (previewPath) {
    assertStoragePath(previewPath, photo.shopId, photo.bookingId, photoId);
    await safeDeleteFile(previewPath);
  }
  if (downloadPath) {
    assertStoragePath(downloadPath, photo.shopId, photo.bookingId, photoId);
    await safeDeleteFile(downloadPath);
  }
  await firestore.collection("daily_care_photos").doc(photoId).delete();
  if (dlSnap.exists) {
    await firestore.collection("daily_care_photo_downloads").doc(photoId)
        .delete();
  }
  if (adjustCount) {
    const dateKey = normalizeString(photo.dateKey) ||
      compactDateKey(photo.recordDate);
    const sessionIndex = toInt(photo.sessionIndex, 0);
    const recId = resolvePhotoRecordId(photo);
    await firestore.runTransaction(async (tx) => {
      const recRef = firestore.collection("daily_care_records").doc(recId);
      const recSnap = await tx.get(recRef);
      const sRef = sessionUsageRef(
          firestore, photo.bookingId, dateKey, sessionIndex,
      );
      const sSnap = await tx.get(sRef);
      if (sSnap.exists) {
        tx.set(sRef, {
          used: Math.max(0, toInt(sSnap.data() && sSnap.data().used, 0) - 1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } else {
        const uRef = usageRef(firestore, photo.bookingId, dateKey);
        const cRef = capacityRef(
            firestore, photo.shopId, photo.roomId, dateKey,
        );
        const uSnap = await tx.get(uRef);
        const cSnap = await tx.get(cRef);
        tx.set(uRef, {
          used: Math.max(0, toInt(uSnap.data() && uSnap.data().used, 0) - 1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        tx.set(cRef, {
          used: Math.max(0, toInt(cSnap.data() && cSnap.data().used, 0) - 1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      tx.set(recRef, {
        photoCount: nextRecordPhotoCount(
            recSnap.data() && recSnap.data().photoCount, -1,
        ),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }
}

async function safeDeleteFile(path) {
  if (!path) {
    return;
  }
  try {
    await admin.storage().bucket().file(path).delete({ignoreNotFound: true});
  } catch (error) {
    const code = error && error.code;
    if (code !== 404 && code !== "object-not-found") {
      throw error;
    }
  }
}

exports.releaseReservation = releaseReservation;
exports.deletePhotoFilesAndDocs = deletePhotoFilesAndDocs;
exports.safeDeleteFile = safeDeleteFile;

exports.lockDailyCareSessionPhotos = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throwHttp("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const sessionIndex = toInt(data.sessionIndex, 0);
      if (!shopId || !bookingId) {
        throwHttp("invalid-argument", "缺少鎖定資料");
      }
      const dateKey = compactDateKey(toDate(data.recordDate) || new Date());
      const clientRecordId = normalizeString(data.dailyCareRecordId);
      const expectedId = expectedDailyCareRecordId(
          bookingId, dateKey, sessionIndex,
      );
      if (clientRecordId && clientRecordId !== expectedId) {
        throwHttp("invalid-argument", "照護紀錄 ID 與日期場次不符");
      }
      const recId = clientRecordId || expectedId;
      await assertStaff(shopId, uid);
      const firestore = admin.firestore();
      const recRef = firestore.collection("daily_care_records").doc(recId);
      await recRef.set({
        photosLocked: true,
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
        publishedByUid: uid,
      }, {merge: true});
      const photos = await firestore.collection("daily_care_photos")
          .where("bookingId", "==", bookingId)
          .get();
      const batch = firestore.batch();
      let photoCount = 0;
      photos.docs.forEach((doc) => {
        const dataDoc = doc.data() || {};
        const bound = normalizeString(dataDoc.dailyCareRecordId);
        let matched = false;
        if (bound) {
          matched = bound === recId;
        } else {
          const key = normalizeString(dataDoc.dateKey) ||
            compactDateKey(dataDoc.recordDate);
          matched = key === dateKey &&
            toInt(dataDoc.sessionIndex, 0) === sessionIndex;
        }
        if (!matched) {
          return;
        }
        photoCount += 1;
        batch.set(doc.ref, {published: true}, {merge: true});
        batch.set(
            firestore.collection("daily_care_photo_downloads").doc(doc.id),
            {published: true},
            {merge: true},
        );
      });
      if (photoCount > 0) {
        await batch.commit();
      }
      return {ok: true, photoCount};
    },
);
