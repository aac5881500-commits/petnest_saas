/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/daily_care_photo_cleanup.test.js
// 功能說明：照護照片到期清理保留文字紀錄，並可重試失敗的檔案。

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {computeExpiresAt} = require("./daily_care_expiry");
const {
  cleanupExpiredBatch,
  processExpiredDownload,
} = require("./cleanup_expired_daily_care_photos");

if (!admin.apps.length) {
  admin.initializeApp({projectId: "petnest-saas-test"});
}

function photoPath(shopId, bookingId, photoId, name) {
  return "daily_care_photos/" + shopId + "/" + bookingId +
    "/room1/20261001/0/" + photoId + "/" + name;
}

function memFirestore() {
  const store = {
    daily_care_photos: new Map(),
    daily_care_photo_downloads: new Map(),
    daily_care_photo_reservations: new Map(),
    daily_care_records: new Map(),
    bookings: new Map(),
    shops: new Map(),
  };
  const queryGets = [];
  function docRef(name, id) {
    const map = store[name];
    return {
      id,
      get: async () => ({
        id,
        exists: map.has(id),
        data: () => map.get(id),
      }),
      set: async (fields, opts) => {
        const prev = map.get(id) || {};
        const next = opts && opts.merge ? {...prev, ...fields} : fields;
        map.set(id, next);
      },
      delete: async () => {
        map.delete(id);
      },
    };
  }
  function query(name, filters) {
    const api = {
      where(field, op, value) {
        return query(name, filters.concat([{field, op, value}]));
      },
      orderBy() {
        return api;
      },
      limit() {
        return api;
      },
      startAfter() {
        return api;
      },
      get: async () => {
        queryGets.push(name);
        const map = store[name] || new Map();
        const docs = [...map.entries()].filter(([, data]) => {
          return filters.every((item) => {
            const left = data[item.field];
            if (item.op === "==") {
              return left === item.value;
            }
            if (item.op === "<=") {
              const l = left && left.toDate ? left.toDate() : left;
              const r = item.value && item.value.toDate ?
                item.value.toDate() : item.value;
              return l instanceof Date && r instanceof Date &&
                l.getTime() <= r.getTime();
            }
            return false;
          });
        }).map(([id, data]) => ({
          id,
          data: () => store[name].get(id) || data,
          ref: docRef(name, id),
        }));
        return {empty: docs.length === 0, size: docs.length, docs};
      },
    };
    return api;
  }
  return {
    store,
    queryGets,
    collection(name) {
      return {
        doc: (id) => docRef(name, id),
        where: (field, op, value) => query(name, [{field, op, value}]),
      };
    },
    batch() {
      const ops = [];
      return {
        set(ref, fields, opts) {
          ops.push(() => ref.set(fields, opts));
        },
        commit: async () => {
          for (let i = 0; i < ops.length; i++) {
            await ops[i]();
          }
        },
      };
    },
  };
}

function seedPhoto(db, spec) {
  const preview = photoPath(spec.shopId, spec.bookingId, spec.photoId,
      "preview.jpg");
  const download = photoPath(spec.shopId, spec.bookingId, spec.photoId,
      "download.jpg");
  db.store.daily_care_photos.set(spec.photoId, {
    shopId: spec.shopId,
    bookingId: spec.bookingId,
    previewUrl: "https://example.test/" + spec.photoId + ".jpg",
    previewStoragePath: preview,
    downloadStoragePath: download,
    expiresAt: spec.expiresAt,
    dailyCareRecordId: spec.recordId,
  });
  db.store.daily_care_photo_downloads.set(spec.photoId, {
    shopId: spec.shopId,
    bookingId: spec.bookingId,
    photoId: spec.photoId,
    downloadStoragePath: download,
    expiresAt: spec.expiresAt,
    published: true,
  });
  return {preview, download};
}

test("CASE 1 未到期照片不刪", async () => {
  const now = new Date("2026-10-06T04:00:00Z");
  const end = new Date(now.getTime() - 60 * 60 * 1000);
  const db = memFirestore();
  const removed = [];
  const spec = {
    shopId: "s1",
    bookingId: "stay-1",
    photoId: "p1",
    recordId: "stay-1_20261005_0",
    expiresAt: new Date(now.getTime() - 60 * 1000),
  };
  seedPhoto(db, spec);
  db.store.bookings.set("stay-1", {
    shopId: "s1",
    status: "completed",
    checkOutAt: end,
    downloadHoursAfterCheckout: 24,
    pointsIssued: 4,
  });
  db.store.daily_care_records.set(spec.recordId, {
    temperature: "26",
    note: "飲食正常",
    photoCount: 1,
  });
  const result = await processExpiredDownload(db, {
    id: "p1",
    data: () => db.store.daily_care_photo_downloads.get("p1"),
    ref: db.collection("daily_care_photo_downloads").doc("p1"),
  }, now, {
    deleteFile: async (path) => {
      removed.push(path);
    },
  });
  assert.equal(result.status, "corrected");
  assert.equal(removed.length, 0);
  assert.equal(
      db.store.daily_care_photos.get("p1").previewUrl.includes("p1"),
      true,
  );
  assert.equal(db.store.bookings.get("stay-1").status, "completed");
  assert.equal(db.store.bookings.get("stay-1").pointsIssued, 4);
});

test("CASE 2-8 到期刪原圖與預覽，紀錄與網址分開處理", async () => {
  const now = new Date("2026-10-06T04:00:00Z");
  const end = new Date(now.getTime() - (24 * 60 * 60 * 1000) - 1000);
  const db = memFirestore();
  const files = new Set();
  const spec = {
    shopId: "s1",
    bookingId: "stay-2",
    photoId: "p2",
    recordId: "stay-2_20261001_0",
    expiresAt: new Date(now.getTime() - 1000),
  };
  const paths = seedPhoto(db, spec);
  files.add(paths.preview);
  files.add(paths.download);
  const record = {
    temperature: "25",
    humidity: "60",
    note: "大小便正常",
    photoCount: 1,
    completedAt: end,
  };
  db.store.daily_care_records.set(spec.recordId, record);
  db.store.bookings.set("stay-2", {
    shopId: "s1",
    status: "completed",
    checkOutAt: end,
    downloadHoursAfterCheckout: 24,
    pointsIssued: 8,
  });
  const stats = await cleanupExpiredBatch(db, {
    now,
    deleteFile: async (path) => {
      files.delete(path);
    },
  });
  assert.equal(stats.success, 1);
  assert.equal(stats.failed, 0);
  assert.equal(files.has(paths.preview), false);
  assert.equal(files.has(paths.download), false);
  const photo = db.store.daily_care_photos.get("p2");
  assert.ok(photo);
  assert.equal(photo.previewUrl, "");
  assert.equal(photo.previewStoragePath, "");
  assert.equal(photo.downloadStoragePath, "");
  assert.equal(photo.photoCleanupStatus, "cleaned");
  assert.equal(db.store.daily_care_photo_downloads.has("p2"), false);
  assert.deepEqual(db.store.daily_care_records.get(spec.recordId), record);
  assert.equal(db.store.bookings.get("stay-2").status, "completed");
  assert.equal(db.store.bookings.get("stay-2").pointsIssued, 8);

  const again = await cleanupExpiredBatch(db, {
    now: new Date(now.getTime() + 60 * 60 * 1000),
    deleteFile: async () => {
      throw new Error("不該再刪");
    },
  });
  assert.equal(again.scanned, 0);
  assert.equal(again.failed, 0);
  assert.equal(again.success, 0);
});

test("CASE 7 檔案已不存在仍視為清理成功", async () => {
  const now = new Date("2026-10-06T04:00:00Z");
  const end = new Date(now.getTime() - 48 * 60 * 60 * 1000);
  const db = memFirestore();
  const spec = {
    shopId: "s1",
    bookingId: "stay-7",
    photoId: "p7",
    recordId: "stay-7_20261001_0",
    expiresAt: new Date(now.getTime() - 1000),
  };
  seedPhoto(db, spec);
  db.store.bookings.set("stay-7", {
    shopId: "s1",
    status: "completed",
    checkOutAt: end,
    downloadHoursAfterCheckout: 24,
  });
  const result = await processExpiredDownload(db, {
    id: "p7",
    data: () => db.store.daily_care_photo_downloads.get("p7"),
    ref: db.collection("daily_care_photo_downloads").doc("p7"),
  }, now, {
    deleteFile: async () => {},
  });
  assert.equal(result.status, "deleted");
  assert.equal(db.store.daily_care_photos.get("p7").photoCleanupStatus,
      "cleaned");
  assert.equal(db.store.daily_care_photos.get("p7").previewUrl, "");
});

test("CASE 9 一張失敗不擋住其他照片，失敗的下一輪可重試", async () => {
  const now = new Date("2026-10-06T04:00:00Z");
  const end = new Date(now.getTime() - 30 * 60 * 60 * 1000);
  const db = memFirestore();
  const files = new Set();
  const bad = {
    shopId: "s1",
    bookingId: "stay-9",
    photoId: "bad",
    recordId: "stay-9_20261001_0",
    expiresAt: new Date(now.getTime() - 1000),
  };
  const good = {
    shopId: "s1",
    bookingId: "stay-9",
    photoId: "good",
    recordId: "stay-9_20261001_0",
    expiresAt: new Date(now.getTime() - 1000),
  };
  const badPaths = seedPhoto(db, bad);
  const goodPaths = seedPhoto(db, good);
  files.add(badPaths.preview);
  files.add(badPaths.download);
  files.add(goodPaths.preview);
  files.add(goodPaths.download);
  db.store.bookings.set("stay-9", {
    shopId: "s1",
    status: "completed",
    checkOutAt: end,
    downloadHoursAfterCheckout: 24,
  });
  let failPreview = true;
  const first = await cleanupExpiredBatch(db, {
    now,
    deleteFile: async (path) => {
      if (failPreview && path === badPaths.preview) {
        const error = new Error("preview delete failed");
        error.code = 500;
        throw error;
      }
      files.delete(path);
    },
  });
  assert.equal(first.success, 1);
  assert.equal(first.failed, 1);
  assert.equal(files.has(goodPaths.preview), false);
  assert.equal(files.has(goodPaths.download), false);
  assert.equal(files.has(badPaths.preview), true);
  assert.equal(db.store.daily_care_photos.get("good").photoCleanupStatus,
      "cleaned");
  assert.equal(db.store.daily_care_photos.get("bad").previewUrl.includes("bad"),
      true);
  assert.equal(db.store.daily_care_photo_downloads.has("bad"), true);
  assert.ok(db.store.daily_care_photo_downloads.get("bad").cleanupFailCount >= 1);

  failPreview = false;
  const retry = await cleanupExpiredBatch(db, {
    now: new Date(now.getTime() + 31 * 60 * 1000),
    deleteFile: async (path) => {
      files.delete(path);
    },
  });
  assert.equal(retry.success, 1);
  assert.equal(retry.failed, 0);
  assert.equal(files.has(badPaths.preview), false);
  assert.equal(files.has(badPaths.download), false);
  assert.equal(db.store.daily_care_photos.get("bad").previewUrl, "");
  assert.equal(db.store.daily_care_photos.get("bad").photoCleanupStatus,
      "cleaned");
});

test("CASE 10 住宿依退房時間加店家保留小時", () => {
  const end = new Date("2026-10-01T04:00:00Z");
  const expires = computeExpiresAt({
    status: "completed",
    checkOutAt: end,
    downloadHoursAfterCheckout: 48,
  });
  assert.equal(expires.getTime(), end.getTime() + 48 * 60 * 60 * 1000);
});

test("CASE 11 安親依實際結束時間加店家保留小時", () => {
  const end = new Date("2026-10-02T02:00:00Z");
  const expires = computeExpiresAt({
    bookingKind: "daycare",
    status: "completed",
    actualEndAt: end,
    checkOutAt: new Date("2026-10-03T00:00:00Z"),
    downloadHoursAfterCheckout: 12,
  });
  assert.equal(expires.getTime(), end.getTime() + 12 * 60 * 60 * 1000);
});

test("CASE 10 住宿到期才刪，未滿店家小時不刪", async () => {
  const now = new Date("2026-10-06T04:00:00Z");
  const db = memFirestore();
  db.store.shops.set("s1", {
    dailyCareSetting: {downloadHoursAfterCheckout: 48},
  });
  const earlyEnd = new Date(now.getTime() - 47 * 60 * 60 * 1000);
  db.store.bookings.set("stay-early", {
    shopId: "s1",
    status: "completed",
    checkOutAt: earlyEnd,
  });
  seedPhoto(db, {
    shopId: "s1",
    bookingId: "stay-early",
    photoId: "early",
    recordId: "rec",
    expiresAt: new Date(now.getTime() - 1000),
  });
  const removed = [];
  const early = await cleanupExpiredBatch(db, {
    now,
    deleteFile: async (path) => {
      removed.push(path);
    },
  });
  assert.equal(early.success, 0);
  assert.equal(removed.length, 0);
  assert.equal(
      db.store.daily_care_photos.get("early").previewUrl.includes("early"),
      true,
  );

  const dueEnd = new Date(now.getTime() - 49 * 60 * 60 * 1000);
  db.store.bookings.set("stay-due", {
    shopId: "s1",
    status: "completed",
    checkOutAt: dueEnd,
    pointsIssued: 2,
  });
  db.store.daily_care_records.set("stay-due_20261001_0", {
    temperature: "27",
    photoCount: 2,
    note: "活動正常",
  });
  seedPhoto(db, {
    shopId: "s1",
    bookingId: "stay-due",
    photoId: "due",
    recordId: "stay-due_20261001_0",
    expiresAt: new Date(now.getTime() - 1000),
  });
  const due = await cleanupExpiredBatch(db, {
    now,
    deleteFile: async (path) => {
      removed.push(path);
    },
  });
  assert.equal(due.success, 1);
  assert.equal(db.store.daily_care_photos.get("due").previewUrl, "");
  assert.equal(db.store.daily_care_records.get("stay-due_20261001_0").photoCount,
      2);
  assert.equal(db.store.daily_care_records.get("stay-due_20261001_0").temperature,
      "27");
  assert.equal(db.store.bookings.get("stay-due").status, "completed");
  assert.equal(db.store.bookings.get("stay-due").pointsIssued, 2);
});

test("CASE 11-12 安親完成後到期清理，照護紀錄仍在", async () => {
  const now = new Date("2026-10-06T04:00:00Z");
  const end = new Date(now.getTime() - 13 * 60 * 60 * 1000);
  const db = memFirestore();
  db.store.shops.set("s1", {
    dailyCareSetting: {downloadHoursAfterCheckout: 12},
  });
  db.store.bookings.set("day-1", {
    shopId: "s1",
    bookingKind: "daycare",
    status: "completed",
    actualEndAt: end,
    checkOutAt: new Date(now.getTime() + 24 * 60 * 60 * 1000),
  });
  const record = {
    temperature: "24",
    humidity: "55",
    note: "睡眠正常",
    photoCount: 1,
    completedAt: end,
  };
  db.store.daily_care_records.set("day-1_20261006_0", record);
  seedPhoto(db, {
    shopId: "s1",
    bookingId: "day-1",
    photoId: "day-photo",
    recordId: "day-1_20261006_0",
    expiresAt: new Date(now.getTime() - 1000),
  });
  const stats = await cleanupExpiredBatch(db, {
    now,
    deleteFile: async () => {},
  });
  assert.equal(stats.success, 1);
  assert.deepEqual(db.store.daily_care_records.get("day-1_20261006_0"), record);
  assert.equal(db.store.daily_care_photos.has("day-photo"), true);
  assert.equal(db.store.daily_care_photos.get("day-photo").previewUrl, "");
  assert.equal(db.store.bookings.get("day-1").status, "completed");
});

test("沒有到期資料時只查下載與預約，不掃照護紀錄", async () => {
  const db = memFirestore();
  db.store.daily_care_records.set("r1", {temperature: "26", photoCount: 1});
  db.store.bookings.set("b1", {status: "completed"});
  const stats = await cleanupExpiredBatch(db, {
    now: new Date("2026-10-06T04:00:00Z"),
  });
  assert.equal(stats.scanned, 0);
  assert.deepEqual(db.queryGets, [
    "daily_care_photo_downloads",
    "daily_care_photo_reservations",
  ]);
});
