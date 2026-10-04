// 檔案名稱：functions/daycare/daycare_capacity.test.js
// 功能說明：每日名額原子占用。同時讀到同一個版本時，只有一筆能提交。

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  CAPACITY_FULL_MESSAGE,
  capacityDocPath,
  capacityReservationPath,
  capacityReservationWrites,
  planDailyCapacityRelease,
  planDailyCapacityReserve,
  readAuthoritativeOccupied,
  seedReservations,
} = require("./daycare_capacity");
const {serviceDateKey} = require("./daycare_utils");
const fs = require("fs");
const path = require("path");

/**
 * @param {Object} initial
 * @return {Object}
 */
function createStore(initial) {
  const docs = new Map();
  const versions = new Map();
  Object.entries(initial || {}).forEach(([key, value]) => {
    docs.set(key, value);
  });
  return {
    get(docPath) {
      const data = docs.get(docPath);
      return {
        exists: data != null,
        version: versions.get(docPath) || 0,
        data: data == null ? null : JSON.parse(JSON.stringify(data)),
      };
    },
    commit(reads, writes) {
      for (const read of reads) {
        const current = versions.get(read.path) || 0;
        if (current !== read.version) {
          return false;
        }
      }
      writes.forEach((write) => {
        docs.set(write.path, JSON.parse(JSON.stringify(write.data)));
        versions.set(write.path, (versions.get(write.path) || 0) + 1);
      });
      return true;
    },
  };
}

/**
 * @param {Object} store
 * @param {function(Object, number): Promise<*>} callback
 * @return {Promise<*>}
 */
async function runTransaction(store, callback) {
  for (let attempt = 0; attempt < 8; attempt++) {
    const reads = [];
    const writes = [];
    const txn = {
      read(docPath) {
        const snap = store.get(docPath);
        reads.push({path: docPath, version: snap.version});
        return snap;
      },
      write(docPath, data) {
        writes.push({path: docPath, data});
      },
    };
    const result = await callback(txn, attempt);
    if (store.commit(reads, writes)) {
      return result;
    }
  }
  throw new Error("transaction contention");
}

/**
 * @param {Object} txn
 * @param {Object} params
 * @return {Object}
 */
function reserveWithTxn(txn, params) {
  const bookingPath = `bookings/${params.bookingId}`;
  const counterPath = capacityDocPath(params.shopId, params.dateKey);
  const reservationPath = capacityReservationPath(
      params.shopId, params.dateKey, params.bookingId,
  );
  const booking = txn.read(bookingPath);
  const counter = txn.read(counterPath);
  const reservation = txn.read(reservationPath);
  if (booking.exists) {
    return {
      reused: true,
      reservedPets: counter.exists ? counter.data.reservedPets : 0,
    };
  }
  const plan = planDailyCapacityReserve({
    dailyMaxPets: params.dailyMaxPets,
    requestedPets: params.requestedPets,
    shopId: params.shopId,
    dateKey: params.dateKey,
    bookingId: params.bookingId,
    counterExists: counter.exists,
    reservedPets: counter.exists ? counter.data.reservedPets : 0,
    reservation: reservation.exists ? reservation.data : null,
    seedBookings: params.seedBookings || [],
  });
  if (!plan.ok) {
    const error = new Error(plan.reason);
    error.code = plan.code;
    throw error;
  }
  capacityReservationWrites(plan).forEach((write) => {
    txn.write(write.path, write.data);
  });
  txn.write(bookingPath, {
    status: "pending",
    shopId: params.shopId,
    serviceDate: params.dateKey,
    petIds: new Array(params.requestedPets).fill("pet"),
  });
  return {ok: true, reservedPets: plan.reservedPets};
}

/**
 * 兩個交易都先讀到同一個 counter 版本，之後才允許提交。
 * @param {Object} store
 * @param {Array<Object>} requests
 * @return {Promise<Array<PromiseSettledResult>>}
 */
function raceReserve(store, requests) {
  let reads = 0;
  let openGate = null;
  const gate = new Promise((resolve) => {
    openGate = resolve;
  });
  return Promise.allSettled(requests.map((params) => {
    return runTransaction(store, async (txn, attempt) => {
      if (attempt === 0) {
        const planned = reserveWithTxn(txn, params);
        reads += 1;
        if (reads === 1) {
          await gate;
        } else if (reads === requests.length) {
          openGate();
        }
        return planned;
      }
      return reserveWithTxn(txn, params);
    });
  }));
}

/**
 * @param {string} shopId
 * @param {string} dateKey
 * @param {number} reservedPets
 * @return {Object}
 */
function seededCounter(shopId, dateKey, reservedPets) {
  return {
    [capacityDocPath(shopId, dateKey)]: {
      dateKey,
      reservedPets,
      initialized: true,
    },
  };
}

const shopId = "shopA";
const date = "2026-10-04";

test("TEST 1 最後一個名額只能有一筆成功", async () => {
  const store = createStore(seededCounter(shopId, date, 4));
  const results = await raceReserve(store, [
    {
      shopId, dateKey: date, bookingId: "A",
      dailyMaxPets: 5, requestedPets: 1,
    },
    {
      shopId, dateKey: date, bookingId: "B",
      dailyMaxPets: 5, requestedPets: 1,
    },
  ]);
  const fulfilled = results.filter((item) => item.status === "fulfilled");
  const rejected = results.filter((item) => item.status === "rejected");
  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.equal(rejected[0].reason.code, "resource-exhausted");
  assert.equal(rejected[0].reason.message, CAPACITY_FULL_MESSAGE);
  assert.equal(store.get(capacityDocPath(shopId, date)).data.reservedPets, 5);
  const bookings = ["A", "B"].filter((id) => {
    return store.get(`bookings/${id}`).exists;
  });
  assert.equal(bookings.length, 1);
});

test("TEST 2 兩個名額都夠時兩筆都成功", async () => {
  const store = createStore(seededCounter(shopId, date, 2));
  const results = await raceReserve(store, [
    {
      shopId, dateKey: date, bookingId: "A",
      dailyMaxPets: 5, requestedPets: 1,
    },
    {
      shopId, dateKey: date, bookingId: "B",
      dailyMaxPets: 5, requestedPets: 1,
    },
  ]);
  assert.equal(results.filter((item) => item.status === "fulfilled").length, 2);
  assert.equal(store.get(capacityDocPath(shopId, date)).data.reservedPets, 4);
});

test("TEST 3 剩下 1 位卻一次要 2 隻時拒絕", () => {
  const plan = planDailyCapacityReserve({
    dailyMaxPets: 5,
    requestedPets: 2,
    shopId,
    dateKey: date,
    bookingId: "A",
    counterExists: true,
    reservedPets: 4,
  });
  assert.equal(plan.ok, false);
  assert.equal(plan.write, false);
  assert.equal(plan.reservedPets, 4);
});

test("TEST 4 三隻寵物剛好補滿", () => {
  const plan = planDailyCapacityReserve({
    dailyMaxPets: 5,
    requestedPets: 3,
    shopId,
    dateKey: date,
    bookingId: "A",
    counterExists: true,
    reservedPets: 2,
  });
  assert.equal(plan.ok, true);
  assert.equal(plan.reservedPets, 5);
  assert.equal(plan.reservation.pets, 3);
});

test("TEST 5 取消兩隻只減一次，TEST 6 重複取消不再減", () => {
  const once = planDailyCapacityRelease({
    counterExists: true,
    reservedPets: 5,
    reservation: {pets: 2},
  });
  assert.equal(once.write, true);
  assert.equal(once.reservedPets, 3);
  const again = planDailyCapacityRelease({
    counterExists: true,
    reservedPets: once.reservedPets,
    reservation: null,
  });
  assert.equal(again.write, false);
  assert.equal(again.reservedPets, 3);
});

test("TEST 7 同一張訂單重送不重複占用", async () => {
  const store = createStore(seededCounter(shopId, date, 2));
  const params = {
    shopId, dateKey: date, bookingId: "same",
    dailyMaxPets: 5, requestedPets: 2,
  };
  const first = await runTransaction(store, async (txn) => {
    return reserveWithTxn(txn, params);
  });
  const second = await runTransaction(store, async (txn) => {
    return reserveWithTxn(txn, params);
  });
  assert.equal(first.reservedPets, 4);
  assert.equal(second.reused, true);
  assert.equal(store.get(capacityDocPath(shopId, date)).data.reservedPets, 4);
});

test("TEST 8 舊訂單 4 隻，counter 不存在時先初始化再搶最後一位", async () => {
  const seedBookings = [1, 2, 3, 4].map((item) => {
    return {
      id: `old-${item}`,
      shopId,
      status: "confirmed",
      bookingKind: "daycare",
      serviceDate: date,
      petIds: [`p${item}`],
    };
  });
  const store = createStore({});
  const results = await raceReserve(store, [
    {
      shopId, dateKey: date, bookingId: "new-1",
      dailyMaxPets: 5, requestedPets: 1, seedBookings,
    },
    {
      shopId, dateKey: date, bookingId: "new-2",
      dailyMaxPets: 5, requestedPets: 1, seedBookings,
    },
  ]);
  assert.equal(results.filter((item) => item.status === "fulfilled").length, 1);
  assert.equal(results.filter((item) => item.status === "rejected").length, 1);
  assert.equal(store.get(capacityDocPath(shopId, date)).data.reservedPets, 5);
});

test("TEST 9 取消的舊訂單不進入初始值", () => {
  const rows = seedReservations([
    {
      id: "keep", shopId, status: "pending", bookingKind: "daycare",
      serviceDate: date, petIds: ["a"],
    },
    {
      id: "gone", shopId, status: "cancelled", bookingKind: "daycare",
      serviceDate: date, petIds: ["b", "c"],
    },
  ], shopId, date);
  assert.deepEqual(rows, [{bookingId: "keep", pets: 1}]);
});

test("TEST 10 與 TEST 11 店家和日期互不影響", () => {
  const plan = planDailyCapacityReserve({
    dailyMaxPets: 5,
    requestedPets: 1,
    shopId: "shopB",
    dateKey: "2026-10-05",
    bookingId: "B",
    counterExists: false,
    seedBookings: [{
      id: "other",
      shopId: "shopA",
      status: "confirmed",
      bookingKind: "daycare",
      serviceDate: date,
      petIds: ["a", "b", "c", "d"],
    }],
  });
  assert.equal(plan.ok, true);
  assert.equal(plan.reservedPets, 1);
  assert.equal(plan.seeds.length, 0);
});

test("TEST 12 一張三隻寵物的舊訂單初始化占 3", () => {
  const rows = seedReservations([{
    id: "multi",
    shopId,
    status: "checked_in",
    bookingKind: "daycare",
    serviceDate: date,
    petIds: ["a", "b", "c"],
  }], shopId, date);
  assert.equal(rows[0].pets, 3);
});

test("TEST 13 台北字面日期不會算到前一天", () => {
  const rows = seedReservations([{
    id: "literal",
    shopId,
    status: "pending",
    bookingKind: "daycare",
    serviceDate: "2026-10-04",
    scheduledStartAt: "2026-10-03T16:00:00.000Z",
    petIds: ["a"],
  }], shopId, "2026-10-04");
  assert.equal(rows.length, 1);
  assert.equal(seedReservations([{
    id: "literal",
    shopId,
    status: "pending",
    bookingKind: "daycare",
    serviceDate: "2026-10-04",
    scheduledStartAt: "2026-10-03T16:00:00.000Z",
    petIds: ["a"],
  }], shopId, "2026-10-03").length, 0);
  assert.equal(serviceDateKey(new Date("2026-10-03T16:00:00.000Z")), "2026-10-04");
});

test("TEST 14 Availability 讀已初始化的 counter，不回訂單", async () => {
  const firestore = {
    collection(name) {
      assert.equal(name, "shops");
      return {
        doc(id) {
          assert.equal(id, shopId);
          return {
            collection(sub) {
              assert.equal(sub, "daycare_capacity");
              return {
                doc() {
                  return {
                    async get() {
                      return {
                        exists: true,
                        data: () => {
                          return {
                            initialized: true,
                            reservedPets: 4,
                            reservations: {secret: "booking-1"},
                          };
                        },
                      };
                    },
                  };
                },
              };
            },
          };
        },
      };
    },
  };
  const occupied = await readAuthoritativeOccupied(
      firestore, shopId, date, [{
        id: "ignored",
        shopId,
        status: "confirmed",
        bookingKind: "daycare",
        serviceDate: date,
        petIds: ["only-one"],
      }],
  );
  assert.equal(occupied, 4);
});

test("TEST 15 與 TEST 16 容量和占用不會變成負數", () => {
  const released = planDailyCapacityRelease({
    counterExists: true,
    reservedPets: 0,
    reservation: {pets: 3},
  });
  assert.equal(released.reservedPets, 0);
  const denied = planDailyCapacityReserve({
    dailyMaxPets: 5,
    requestedPets: 1,
    shopId,
    dateKey: date,
    bookingId: "A",
    counterExists: true,
    reservedPets: 5,
  });
  assert.equal(denied.ok, false);
  assert.ok(denied.capacity >= 0);
  assert.ok(denied.reservedPets >= 0);
});

test("TEST 17 成功占用不會超過容量", () => {
  const plan = planDailyCapacityReserve({
    dailyMaxPets: 5,
    requestedPets: 1,
    shopId,
    dateKey: date,
    bookingId: "A",
    counterExists: true,
    reservedPets: 4,
  });
  assert.equal(plan.reservedPets <= plan.capacity, true);
  const over = planDailyCapacityReserve({
    dailyMaxPets: 5,
    requestedPets: 2,
    shopId,
    dateKey: date,
    bookingId: "B",
    counterExists: true,
    reservedPets: 4,
  });
  assert.equal(over.write, false);
  assert.equal(over.reservedPets, 4);
});

test("沒有每日上限時仍記錄占用但不拒絕", async () => {
  const store = createStore({});
  const results = await raceReserve(store, [
    {
      shopId, dateKey: date, bookingId: "A",
      dailyMaxPets: 0, requestedPets: 1,
    },
    {
      shopId, dateKey: date, bookingId: "B",
      dailyMaxPets: 0, requestedPets: 1,
    },
  ]);
  assert.equal(results.filter((item) => item.status === "fulfilled").length, 2);
  assert.equal(store.get(capacityDocPath(shopId, date)).data.reservedPets, 2);
});

test("建立訂單的容量占用和 booking 在同一段 transaction", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "create_daycare_booking.js"),
      "utf8",
  );
  const body = source.slice(source.indexOf("firestore.runTransaction"));
  assert.match(body, /readDailyCapacityReserve\(/);
  assert.match(body, /commitDailyCapacityReserve\(/);
  assert.match(body, /commitRoomTypeHold\(/);
  assert.match(body, /transaction\.set\(bookingRef/);
  const reserveAt = body.indexOf("readDailyCapacityReserve(");
  const roomAt = body.indexOf("loadRoomTypeHoldState(");
  const commitAt = body.indexOf("commitDailyCapacityReserve(");
  const bookingAt = body.indexOf("transaction.set(bookingRef");
  assert.ok(reserveAt < roomAt);
  assert.ok(roomAt < commitAt);
  assert.ok(commitAt < bookingAt);
});
