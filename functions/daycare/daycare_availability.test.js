// 檔案名稱：functions/daycare/daycare_availability.test.js
// 功能說明：安親剩餘名額聚合：不回傳其他顧客，取消與跨店不計入。

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const {
  occupiedPetsForDate,
  dailyPetAvailability,
  dailyPetCapacityAllows,
  bookingServiceDate,
  publicRoomTypeSummary,
  remainingRoomsFromData,
} = require("./daycare_occupancy");
const {serviceDateKey} = require("./daycare_utils");
const {
  getDaycareAvailabilityHandler,
  buildDaycareAvailability,
} = require("./get_daycare_availability");

const shopId = "shopA";
const date = "2026-10-04";

/**
 * @param {Object} extra
 * @return {Object}
 */
function booking(extra) {
  return {
    id: "b1",
    shopId,
    status: "confirmed",
    bookingKind: "daycare",
    serviceDate: date,
    petIds: ["p1"],
    ...extra,
  };
}

describe("daily pet availability", () => {
  it("TEST 1 容量 5、無人占用，剩餘 5", () => {
    const result = dailyPetAvailability({capacity: 5, occupied: 0});
    assert.equal(result.remaining, 5);
    assert.equal(result.available, true);
  });

  it("TEST 2 容量 5、占用 3，剩餘 2", () => {
    const occupied = occupiedPetsForDate([
      booking({id: "a", petIds: ["p1"]}),
      booking({id: "b", petIds: ["p2", "p3"]}),
    ], {shopId, serviceDate: date});
    const result = dailyPetAvailability({capacity: 5, occupied});
    assert.equal(occupied, 3);
    assert.equal(result.remaining, 2);
  });

  it("TEST 3 額滿時 available 為 false", () => {
    const result = dailyPetAvailability({capacity: 5, occupied: 5});
    assert.equal(result.remaining, 0);
    assert.equal(result.available, false);
  });

  it("TEST 4 超賣時剩餘不得為負數", () => {
    const result = dailyPetAvailability({capacity: 5, occupied: 6});
    assert.equal(result.remaining, 0);
  });

  it("TEST 5 取消一隻後名額從 2 回到 3", () => {
    const active = [
      booking({id: "a", petIds: ["p1"]}),
      booking({id: "b", petIds: ["p2"]}),
      booking({id: "c", petIds: ["p3"]}),
    ];
    const before = occupiedPetsForDate(active, {shopId, serviceDate: date});
    assert.equal(before, 3);
    assert.equal(dailyPetAvailability({
      capacity: 5, occupied: before,
    }).remaining, 2);
    const after = occupiedPetsForDate([
      booking({id: "a", petIds: ["p1"]}),
      booking({id: "b", status: "cancelled", petIds: ["p2"]}),
      booking({id: "c", petIds: ["p3"]}),
    ], {shopId, serviceDate: date});
    assert.equal(after, 2);
    assert.equal(dailyPetAvailability({
      capacity: 5, occupied: after,
    }).remaining, 3);
  });

  it("TEST 6 一張訂單三隻寵物占 3 個名額", () => {
    const occupied = occupiedPetsForDate([
      booking({petIds: ["p1", "p2", "p3"]}),
    ], {shopId, serviceDate: date});
    assert.equal(occupied, 3);
    assert.equal(dailyPetAvailability({
      capacity: 5, occupied,
    }).remaining, 2);
  });

  it("TEST 7 其他店的訂單不計入", () => {
    const occupied = occupiedPetsForDate([
      booking({petIds: ["p1"]}),
      booking({id: "other", shopId: "shopB", petIds: ["x1", "x2", "x3"]}),
    ], {shopId, serviceDate: date});
    assert.equal(occupied, 1);
  });

  it("TEST 8 其他日期不計入", () => {
    const occupied = occupiedPetsForDate([
      booking({petIds: ["p1"]}),
      booking({id: "tomorrow", serviceDate: "2026-10-05", petIds: ["x"]}),
    ], {shopId, serviceDate: date});
    assert.equal(occupied, 1);
  });

  it("TEST 10 independentPlan 使用 dailyMaxPets", () => {
    const occupied = occupiedPetsForDate([
      booking({petIds: ["p1", "p2"]}),
    ], {shopId, serviceDate: date});
    const verdict = dailyPetCapacityAllows({
      capacity: 5,
      occupied,
      additionalPets: 4,
    });
    assert.equal(verdict.ok, false);
    assert.equal(verdict.remaining, 3);
  });
});

describe("room type availability", () => {
  const start = new Date("2026-10-04T01:00:00.000Z");
  const end = new Date("2026-10-04T09:00:00.000Z");
  const rooms = [
    {id: "a1", roomTypeId: "typeA", enabled: true, capacity: 2},
    {id: "b1", roomTypeId: "typeB", enabled: true, capacity: 2},
  ];

  it("TEST 9 房型 A 不會被房型 B 占用", () => {
    const computed = remainingRoomsFromData({
      rooms,
      bookings: [{
        id: "b",
        status: "confirmed",
        bookingKind: "daycare",
        roomId: "b1",
        requestedRoomTypeId: "typeB",
        roomTypeId: "typeB",
        scheduledStartAt: start,
        scheduledEndAt: end,
      }],
      roomTypeId: "typeA",
      startAt: start,
      endAt: end,
    });
    const summary = publicRoomTypeSummary(computed, "typeA");
    assert.equal(summary.roomTypeId, "typeA");
    assert.equal(summary.remaining, 1);
    assert.equal(summary.capacity, 1);
    assert.equal(Object.hasOwn(summary, "bookingId"), false);
  });
});

describe("taipei date", () => {
  it("TEST 14 字面日期不因 UTC 少一天", () => {
    assert.equal(bookingServiceDate({
      serviceDate: "2026-10-04",
      scheduledStartAt: new Date("2026-10-03T16:00:00.000Z"),
    }), "2026-10-04");
    assert.equal(
        serviceDateKey(new Date("2026-10-03T16:00:00.000Z")),
        "2026-10-04",
    );
    assert.notEqual(
        serviceDateKey(new Date("2026-10-03T16:00:00.000Z")),
        "2026-10-03",
    );
  });
});

/**
 * @param {Object} state
 * @return {Object}
 */
function memoryDb(state) {
  /**
   * @param {string} name
   * @param {Object|Array} bucket
   * @return {Object}
   */
  function collection(name, bucket) {
    const rows = Array.isArray(bucket) ? bucket : [];
    const api = {
      filters: [],
      where(field, op, value) {
        api.filters.push({field, op, value});
        return api;
      },
      limit() {
        return api;
      },
      async get() {
        let list = rows.slice();
        api.filters.forEach((filter) => {
          if (filter.op === "==") {
            list = list.filter((row) => row[filter.field] === filter.value);
          }
          if (filter.op === "in") {
            list = list.filter((row) => filter.value.includes(row[filter.field]));
          }
        });
        return {
          empty: list.length === 0,
          docs: list.map((row) => {
            return {id: row.id, data: () => row};
          }),
        };
      },
      doc(id) {
        const nested = bucket && !Array.isArray(bucket) ? bucket[id] : null;
        return {
          async get() {
            if (name === "shops") {
              const shop = state.shops[id];
              return {
                exists: Boolean(shop),
                data: () => shop ? shop.data : null,
              };
            }
            return {
              exists: nested != null && !nested.docs,
              data: () => nested && !nested.docs ? nested : null,
            };
          },
          collection(sub) {
            const shop = state.shops[id] || {};
            return collection(sub, shop[sub] || []);
          },
        };
      },
    };
    return api;
  }
  return {
    collection(name) {
      if (name === "bookings") {
        return collection(name, state.bookings || []);
      }
      if (name === "shops") {
        return collection(name, state.shops || {});
      }
      return collection(name, []);
    },
  };
}

describe("availability function", () => {
  const firestore = memoryDb({
    shops: {
      shopA: {
        data: {daycareEnabled: true, name: "A"},
        daycare_settings: {
          main: {
            enabled: true,
            dailyMaxPets: 5,
            pricingMode: "independentPlan",
            roomTypes: [{roomTypeId: "typeA"}],
          },
        },
        rooms: [],
        room_types: {},
      },
    },
    bookings: [
      booking({
        userId: "other-customer",
        customerName: "王小明",
        customerPhone: "0912000000",
        email: "a@pet.test",
        petIds: ["pet-secret"],
        pets: [{name: "豆豆"}],
      }),
    ],
  });

  it("TEST 11 未登入拒絕", async () => {
    await assert.rejects(
        () => getDaycareAvailabilityHandler({data: {shopId, date}}, firestore),
        (error) => error.code === "unauthenticated",
    );
  });

  it("TEST 12 其他店不存在的房型拒絕", async () => {
    await assert.rejects(
        () => buildDaycareAvailability(firestore, {
          shopId,
          date,
          roomTypeId: "shopB-only",
        }),
        (error) => error.code === "invalid-argument",
    );
  });

  it("TEST 13 回應沒有其他顧客資料", async () => {
    const result = await buildDaycareAvailability(firestore, {shopId, date});
    const encoded = JSON.stringify(result);
    [
      "bookingId",
      "userId",
      "customerName",
      "customerPhone",
      "email",
      "petId",
      "pet-secret",
      "王小明",
      "豆豆",
    ].forEach((secret) => {
      assert.equal(encoded.includes(secret), false, secret);
    });
    assert.equal(result.days[0].occupied, 1);
    assert.equal(result.days[0].remaining, 4);
    assert.equal(result.pricingMode, "independentPlan");
  });

  it("一次不能查超過 31 天", async () => {
    const dates = [];
    for (let day = 1; day <= 32; day += 1) {
      dates.push(`2026-10-${String(day).padStart(2, "0")}`);
    }
    await assert.rejects(
        () => buildDaycareAvailability(firestore, {shopId, dates}),
        (error) => error.code === "invalid-argument",
    );
  });
});

describe("create booking still rechecks capacity", () => {
  it("TEST 15 建立前仍呼叫 assertAvailable 與每日名額", () => {
    const source = fs.readFileSync(
        path.join(__dirname, "create_daycare_booking.js"),
        "utf8",
    );
    assert.match(source, /assertAvailable\(/);
    assert.match(source, /readDailyCapacityReserve\(/);
    assert.match(source, /commitDailyCapacityReserve\(/);
    assert.match(source, /assertRoomTypeCapacity\(/);
  });
});
