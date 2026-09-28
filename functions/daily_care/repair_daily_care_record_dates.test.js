/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/repair_daily_care_record_dates.test.js
// 功能說明：住宿 9/28～9/30 早一天的回報與照片校正；安親不改。

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  planAccommodationDateRepair,
  repairAccommodationRecords,
} = require("./repair_daily_care_record_dates");

if (!admin.apps.length) {
  admin.initializeApp({projectId: "petnest-saas-test"});
}

function memFirestore() {
  const store = {
    bookings: new Map(),
    daily_care_records: new Map(),
    daily_care_photos: new Map(),
    daily_care_photo_downloads: new Map(),
  };

  function refOf(name, id) {
    const map = store[name];
    const ref = {
      id,
      get: async () => ({
        id,
        exists: map.has(id),
        data: () => map.get(id),
        ref,
      }),
      set: async (fields, opts) => {
        const prev = map.get(id) || {};
        map.set(id, opts && opts.merge ? {...prev, ...fields} : {...fields});
      },
      delete: async () => {
        map.delete(id);
      },
    };
    return ref;
  }

  function col(name) {
    const map = store[name];
    return {
      doc: (id) => refOf(name, id),
      where(field, op, value) {
        return {
          get: async () => ({
            docs: [...map.entries()]
                .filter(([, data]) => data[field] === value)
                .map(([id]) => {
                  const ref = refOf(name, id);
                  return {id, ref, data: () => map.get(id)};
                }),
          }),
        };
      },
    };
  }

  return {
    store,
    collection: col,
    async runTransaction(fn) {
      const ops = [];
      const tx = {
        get: (ref) => ref.get(),
        set: (ref, data, opts) => ops.push(() => ref.set(data, opts)),
        delete: (ref) => ops.push(() => ref.delete()),
      };
      const result = await fn(tx);
      for (let i = 0; i < ops.length; i++) {
        await ops[i]();
      }
      return result;
    },
  };
}

test("住宿 9/28～9/30 的合法回報日是 9/28、9/29", () => {
  const plan = planAccommodationDateRepair({
    legalKeys: ["20260928", "20260929"],
    serviceDateKeys: ["20260927", "20260928"],
    recordDateKeys: ["20260927", "20260928"],
  });
  assert.equal(plan.repair, true);
  assert.deepEqual(plan.legalKeys, ["20260928", "20260929"]);
  assert.deepEqual(plan.moves, [
    {from: "20260928", to: "20260929"},
    {from: "20260927", to: "20260928"},
  ]);
});

test("舊 9/27 第 1 場與照片校正到 9/28 第 1 場", async () => {
  const db = memFirestore();
  const bookingId = "stay1";
  db.store.bookings.set(bookingId, {
    shopId: "shop1",
    bookingKind: "accommodation",
    startDate: new Date("2026-09-28T00:00:00+08:00"),
    endDate: new Date("2026-09-30T00:00:00+08:00"),
    dailyCareEntitlement: {
      enabled: true,
      finalReports: 1,
      serviceDates: ["2026/09/27", "2026/09/28"],
    },
  });
  db.store.daily_care_records.set("stay1_20260927_0", {
    shopId: "shop1",
    bookingId,
    sessionIndex: 0,
    values: {ate: true},
    petNotes: {momo: "正常"},
    photoCount: 1,
    photosLocked: true,
    reportStatus: "completed",
    createdAt: "created-27",
    createdBy: "staff",
    completedAt: "done-27",
    updatedAt: "updated-27",
  });
  db.store.daily_care_records.set("stay1_20260928_0", {
    shopId: "shop1",
    bookingId,
    sessionIndex: 0,
    values: {ate: false},
    photoCount: 0,
    reportStatus: "completed",
    createdAt: "created-28",
  });
  db.store.daily_care_photos.set("photo1", {
    shopId: "shop1",
    bookingId,
    dailyCareRecordId: "stay1_20260927_0",
    dateKey: "20260927",
    sessionIndex: 0,
    previewStoragePath: "daily_care_photos/shop1/stay1/photo1/preview.jpg",
    downloadStoragePath: "daily_care_photos/shop1/stay1/photo1/download.jpg",
  });
  db.store.daily_care_photo_downloads.set("photo1", {
    shopId: "shop1",
    bookingId,
    photoId: "photo1",
    dailyCareRecordId: "stay1_20260927_0",
    sessionIndex: 0,
    downloadStoragePath: "daily_care_photos/shop1/stay1/photo1/download.jpg",
  });

  const result = await repairAccommodationRecords(db, "shop1", bookingId);
  assert.equal(result.repaired, true);
  assert.deepEqual(result.oldRecordIds, [
    "stay1_20260928_0",
    "stay1_20260927_0",
  ]);
  assert.deepEqual(result.newRecordIds, [
    "stay1_20260929_0",
    "stay1_20260928_0",
  ]);
  assert.equal(result.updatedPhotoCount, 1);
  assert.equal(db.store.daily_care_records.has("stay1_20260927_0"), false);
  assert.equal(db.store.daily_care_records.get("stay1_20260928_0").values.ate, true);
  assert.equal(db.store.daily_care_records.get("stay1_20260928_0").petNotes.momo, "正常");
  assert.equal(db.store.daily_care_records.get("stay1_20260928_0").serviceDate, "2026-09-28");
  assert.equal(db.store.daily_care_records.get("stay1_20260928_0").createdAt, "created-27");
  assert.equal(db.store.daily_care_records.get("stay1_20260929_0").values.ate, false);
  const photo = db.store.daily_care_photos.get("photo1");
  assert.equal(photo.dailyCareRecordId, "stay1_20260928_0");
  assert.equal(photo.dateKey, "20260928");
  assert.equal(photo.sessionIndex, 0);
  assert.equal(
      photo.previewStoragePath,
      "daily_care_photos/shop1/stay1/photo1/preview.jpg",
  );
  const download = db.store.daily_care_photo_downloads.get("photo1");
  assert.equal(download.dailyCareRecordId, "stay1_20260928_0");
  assert.equal(download.sessionIndex, 0);
  assert.equal(
      download.downloadStoragePath,
      "daily_care_photos/shop1/stay1/photo1/download.jpg",
  );
  assert.deepEqual(
      db.store.bookings.get(bookingId).dailyCareEntitlement.serviceDates,
      ["2026/09/28", "2026/09/29"],
  );
});

test("日期沒有整段早一天時不修改", async () => {
  const db = memFirestore();
  db.store.bookings.set("stay2", {
    shopId: "shop1",
    bookingKind: "accommodation",
    startDate: new Date("2026-09-28T00:00:00+08:00"),
    endDate: new Date("2026-09-30T00:00:00+08:00"),
    dailyCareEntitlement: {
      serviceDates: ["2026/09/28", "2026/09/29"],
    },
  });
  db.store.daily_care_records.set("stay2_20260928_0", {
    bookingId: "stay2",
    values: {ate: true},
  });
  const result = await repairAccommodationRecords(db, "shop1", "stay2");
  assert.equal(result.repaired, false);
  assert.equal(result.skippedReason, "回報日期不是整段往前偏一天");
  assert.equal(db.store.daily_care_records.get("stay2_20260928_0").values.ate, true);
});

test("安親日期不受住宿校正影響", async () => {
  const db = memFirestore();
  db.store.bookings.set("day1", {
    shopId: "shop1",
    bookingKind: "daycare",
    serviceDate: "2026-09-28",
    startDate: new Date("2026-09-28T00:00:00+08:00"),
    endDate: new Date("2026-09-30T00:00:00+08:00"),
    dailyCareEntitlement: {
      serviceDates: ["2026/09/27"],
    },
  });
  db.store.daily_care_records.set("day1_20260927_0", {
    bookingId: "day1",
    values: {play: true},
  });
  const result = await repairAccommodationRecords(db, "shop1", "day1");
  assert.equal(result.repaired, false);
  assert.equal(result.skippedReason, "不是住宿訂單");
  assert.equal(db.store.daily_care_records.has("day1_20260927_0"), true);
  assert.deepEqual(
      db.store.bookings.get("day1").dailyCareEntitlement.serviceDates,
      ["2026/09/27"],
  );
});
