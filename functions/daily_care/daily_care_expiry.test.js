/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/daily_care_expiry.test.js
// 功能說明：刪除前驗證、期限分批寫入、preview／download 對齊與重試。

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  evaluateCleanupDecision,
  planStampWrites,
  stampExpiresForBooking,
  nextRetryAt,
  STAMP_CHUNK,
} = require("./daily_care_expiry");

if (!admin.apps.length) {
  admin.initializeApp({projectId: "petnest-saas-test"});
}

function memFirestore() {
  const store = {
    daily_care_photos: new Map(),
    daily_care_photo_downloads: new Map(),
    bookings: new Map(),
  };
  function col(name) {
    const map = store[name];
    return {
      where(field, op, value) {
        return {
          get: async () => ({
            docs: [...map.entries()]
                .filter(([, data]) => data[field] === value)
                .map(([id, data]) => ({
                  id,
                  data: () => data,
                  ref: col(name).doc(id),
                })),
          }),
        };
      },
      doc(id) {
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
        };
      },
    };
  }
  return {
    store,
    collection: col,
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

test("訂單不存在、shopId 不符不得刪除", () => {
  const now = new Date("2026-09-10T12:00:00Z");
  const missing = evaluateCleanupDecision({
    bookingExists: false,
    booking: {},
    download: {shopId: "s1", bookingId: "b1"},
    photo: {shopId: "s1", bookingId: "b1"},
    now,
  });
  assert.equal(missing.action, "hold");
  const mismatch = evaluateCleanupDecision({
    bookingExists: true,
    booking: {shopId: "other", status: "completed",
      checkOutAt: new Date("2026-09-01T00:00:00Z")},
    download: {shopId: "s1", bookingId: "b1"},
    photo: {shopId: "s1", bookingId: "b1"},
    now,
  });
  assert.equal(mismatch.action, "hold");
});

test("舊 metadata 已過期但有效期限未到不得刪除", () => {
  const now = new Date("2026-09-10T12:00:00Z");
  const decision = evaluateCleanupDecision({
    bookingExists: true,
    booking: {
      shopId: "s1",
      status: "completed",
      checkOutAt: new Date("2026-09-10T00:00:00Z"),
    },
    download: {
      shopId: "s1",
      bookingId: "b1",
      expiresAt: new Date("2026-09-09T00:00:00Z"),
    },
    photo: {shopId: "s1", bookingId: "b1"},
    now,
  });
  assert.equal(decision.action, "correct_expiry");
});

test("已恢復服務或延住不沿用舊期限刪除", () => {
  const now = new Date("2026-09-10T12:00:00Z");
  const restored = evaluateCleanupDecision({
    bookingExists: true,
    booking: {shopId: "s1", status: "checked_in"},
    download: {
      shopId: "s1",
      bookingId: "b1",
      expiresAt: new Date("2026-09-01T00:00:00Z"),
    },
    photo: {shopId: "s1", bookingId: "b1"},
    now,
  });
  assert.equal(restored.action, "clear_expiry");
});

test("服務已結束且有效期限已到才刪除", () => {
  const now = new Date("2026-09-12T12:00:00Z");
  const decision = evaluateCleanupDecision({
    bookingExists: true,
    booking: {
      shopId: "s1",
      status: "completed",
      checkOutAt: new Date("2026-09-10T00:00:00Z"),
    },
    download: {shopId: "s1", bookingId: "b1"},
    photo: {shopId: "s1", bookingId: "b1"},
    now,
  });
  assert.equal(decision.action, "delete");
});

test("preview 有期限但 download 缺期限要補，不因 preview 已有值跳過", () => {
  const desired = new Date("2026-09-11T00:00:00Z");
  const plan = planStampWrites(
      {expiresAt: desired},
      {},
      desired,
  );
  assert.equal(plan.skipped, false);
  assert.equal(plan.updatePhoto, false);
  assert.equal(plan.updateDownload, true);
  assert.equal(plan.fillMissingDownload, true);
});

test("重複觸發且兩份期限已一致不重設", () => {
  const desired = new Date("2026-09-11T00:00:00Z");
  const plan = planStampWrites(
      {expiresAt: desired},
      {expiresAt: desired},
      desired,
  );
  assert.equal(plan.skipped, true);
});

test("失敗重試時間會後退且有上限", () => {
  const now = new Date("2026-09-10T00:00:00Z");
  const first = nextRetryAt(now, 0);
  const later = nextRetryAt(now, 8);
  assert.ok(first.getTime() > now.getTime());
  assert.ok(later.getTime() - now.getTime() <= 6 * 60 * 60 * 1000);
});

test("大量照片分批寫入期限，且可補 download", async () => {
  const fs = memFirestore();
  const bookingId = "b-big";
  const end = new Date("2026-09-08T00:00:00Z");
  const count = STAMP_CHUNK * 2 + 5;
  for (let i = 0; i < count; i++) {
    const id = "p" + String(i).padStart(3, "0");
    fs.store.daily_care_photos.set(id, {
      bookingId,
      shopId: "s1",
      expiresAt: i === 0 ? admin.firestore.Timestamp.fromDate(
          new Date("2026-09-09T00:00:00Z"),
      ) : null,
    });
    if (i !== 0) {
      fs.store.daily_care_photo_downloads.set(id, {
        bookingId,
        shopId: "s1",
      });
    } else {
      fs.store.daily_care_photo_downloads.set(id, {
        bookingId,
        shopId: "s1",
      });
    }
  }
  const firstPhoto = fs.store.daily_care_photos.get("p000");
  firstPhoto.expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(end.getTime() + 24 * 60 * 60 * 1000),
  );
  delete fs.store.daily_care_photo_downloads.get("p000").expiresAt;
  const result = await stampExpiresForBooking(fs, bookingId, {
    status: "completed",
    checkOutAt: end,
    shopId: "s1",
  });
  assert.ok(result.updated >= count);
  assert.ok(result.aligned >= 1);
  const filled = fs.store.daily_care_photo_downloads.get("p000");
  assert.ok(filled.expiresAt);
  const lastId = "p" + String(count - 1).padStart(3, "0");
  const last = fs.store.daily_care_photos.get(lastId);
  assert.ok(last.expiresAt);
});

test("超過 40 筆時游標可繼續，前面 hold 不擋住後面刪除", () => {
  const now = new Date("2026-09-12T12:00:00Z");
  const items = [];
  for (let i = 0; i < 45; i++) {
    items.push({
      id: "d" + i,
      hold: i < 40,
      bookingExists: i >= 40,
      booking: i >= 40 ? {
        shopId: "s1",
        status: "completed",
        checkOutAt: new Date("2026-09-10T00:00:00Z"),
      } : {},
      download: {shopId: "s1", bookingId: i >= 40 ? "b-ok" : ""},
      photo: {shopId: "s1", bookingId: i >= 40 ? "b-ok" : ""},
    });
  }
  const deleted = [];
  const held = [];
  const batchSize = 40;
  let cursor = 0;
  let batches = 0;
  while (batches < 3 && cursor < items.length) {
    const page = items.slice(cursor, cursor + batchSize);
    batches += 1;
    page.forEach((item) => {
      const decision = evaluateCleanupDecision({
        bookingExists: item.bookingExists,
        booking: item.booking,
        download: item.download,
        photo: item.photo,
        now,
      });
      if (decision.action === "delete") {
        deleted.push(item.id);
      } else {
        held.push(item.id);
      }
    });
    cursor += page.length;
  }
  assert.equal(deleted.length, 5);
  assert.equal(held.length, 40);
  assert.equal(batches, 2);
});
