// 住宿 Availability 使用與建單相同的 remainingRoomsFromData。
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {projectStayAvailability} = require("./get_stay_availability");

const shopId = "shopA";
const rooms = [1, 2, 3, 4, 5].map((index) => {
  return {
    id: `r${index}`,
    shopId,
    roomTypeId: "vip",
    enabled: true,
    status: "available",
    capacity: 2,
  };
});
const roomTypes = [{id: "vip", shopId, capacity: 2, name: "景觀房"}];
const stayStart = new Date("2026-10-01T00:00:00+08:00");
const stayEnd = new Date("2026-10-03T00:00:00+08:00");

/**
 * @param {Array<string>} roomIds
 * @param {string} status
 * @return {Array<Object>}
 */
function assignedStays(roomIds, status) {
  return roomIds.map((roomId, index) => {
    return {
      id: `stay-${status}-${index}`,
      shopId,
      status,
      bookingKind: "accommodation",
      roomId,
      roomTypeId: "vip",
      userId: `user-${index}`,
      customerName: "不該出現",
      phone: "0900000000",
      petIds: [`pet-${index}`],
      startDate: stayStart,
      endDate: stayEnd,
    };
  });
}

/**
 * @param {Object} extra
 * @return {Object}
 */
function project(extra) {
  return projectStayAvailability({
    shopId,
    shop: {housekeepingSetting: {autoCleaningAfterCheckout: false}},
    rooms,
    roomTypes,
    bookings: [],
    occupancies: [],
    calendarEntries: [],
    holds: [],
    dates: ["2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03"],
    startDate: "2026-10-01",
    endDate: "2026-10-03",
    petCount: 1,
    ...extra,
  });
}

/**
 * @param {Object} value
 * @param {Set<string>} found
 */
function collectKeys(value, found) {
  if (Array.isArray(value)) {
    value.forEach((item) => collectKeys(item, found));
    return;
  }
  if (value && typeof value === "object") {
    Object.keys(value).forEach((key) => {
      found.add(key);
      collectKeys(value[key], found);
    });
  }
}

describe("stay availability", () => {
  it("TEST 11 five rooms and none occupied", () => {
    const day = project({}).dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.total, 5);
    assert.equal(day.remaining, 5);
    assert.equal(day.occupied, 0);
    assert.equal(day.available, true);
  });

  it("TEST 12 five rooms and three occupied", () => {
    const day = project({
      bookings: assignedStays(["r1", "r2", "r3"], "confirmed"),
    }).dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.total, 5);
    assert.equal(day.occupied, 3);
    assert.equal(day.remaining, 2);
  });

  it("TEST 13 five rooms and five occupied", () => {
    const day = project({
      bookings: assignedStays(["r1", "r2", "r3", "r4", "r5"], "confirmed"),
    }).dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.remaining, 0);
    assert.equal(day.available, false);
  });

  it("TEST 14 remaining is never negative", () => {
    const bookings = [1, 2, 3, 4, 5, 6].map((index) => {
      return {
        id: `pending-${index}`,
        shopId,
        status: "pending",
        bookingKind: "accommodation",
        roomId: "",
        roomTypeId: "vip",
        startDate: stayStart,
        endDate: stayEnd,
      };
    });
    const day = project({bookings})
        .dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.remaining, 0);
    assert.ok(day.remaining >= 0);
  });

  it("TEST 15 cancelled stays do not occupy", () => {
    const day = project({
      bookings: assignedStays(["r1", "r2"], "cancelled"),
    }).dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.remaining, 5);
  });

  it("TEST 16 unassigned pending stays still occupy", () => {
    const day = project({
      bookings: [{
        id: "pending-open",
        shopId,
        status: "pending",
        bookingKind: "accommodation",
        roomId: "",
        requestedRoomTypeId: "vip",
        userId: "customerA",
        startDate: stayStart,
        endDate: stayEnd,
      }],
    }).dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.remaining, 4);
  });

  it("TEST 17 another shop does not affect this shop", () => {
    const day = project({
      bookings: [{
        id: "other-shop",
        shopId: "shopB",
        status: "confirmed",
        bookingKind: "accommodation",
        roomId: "r1",
        roomTypeId: "vip",
        startDate: stayStart,
        endDate: stayEnd,
      }],
      calendarEntries: [{
        shopId: "shopB",
        roomId: "r1",
        date: "2026-10-01",
        status: "booked",
        bookingId: "other-shop",
      }],
    }).dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.remaining, 5);
  });

  it("TEST 18 another room type does not affect this type", () => {
    const result = project({
      rooms: rooms.concat([{
        id: "std1",
        shopId,
        roomTypeId: "std",
        enabled: true,
        status: "available",
      }]),
      roomTypes: roomTypes.concat([{id: "std", shopId, capacity: 1}]),
      bookings: [{
        id: "std-stay",
        shopId,
        status: "confirmed",
        bookingKind: "accommodation",
        roomId: "std1",
        roomTypeId: "std",
        startDate: stayStart,
        endDate: stayEnd,
      }],
      roomTypeId: "vip",
    });
    const day = result.dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.remaining, 5);
    assert.deepEqual(day.roomTypes.map((row) => row.roomTypeId), ["vip"]);
  });

  it("TEST 19 October 1 to 3 does not occupy September 30", () => {
    const result = project({
      bookings: assignedStays(["r1"], "confirmed"),
    });
    const before = result.dates.find((row) => row.date === "2026-09-30");
    const firstNight = result.dates.find((row) => row.date === "2026-10-01");
    assert.equal(before.remaining, 5);
    assert.equal(firstNight.remaining, 4);
  });

  it("TEST 20 checkout day is free when cleaning lock is off", () => {
    const day = project({
      bookings: assignedStays(["r1"], "confirmed"),
    }).dates.find((row) => row.date === "2026-10-03");
    assert.equal(day.remaining, 5);
    assert.equal(day.available, true);
  });

  it("TEST 21 checkout day stays locked when cleaning lock is on", () => {
    const day = project({
      shop: {housekeepingSetting: {autoCleaningAfterCheckout: true}},
      bookings: assignedStays(["r1"], "confirmed"),
      calendarEntries: [{
        shopId,
        roomId: "r1",
        date: "2026-10-03",
        status: "checkout_cleaning",
        bookingId: "stay-confirmed-0",
      }],
    }).dates.find((row) => row.date === "2026-10-03");
    assert.equal(day.remaining, 4);
    assert.equal(day.available, true);
  });

  it("TEST 22 disabled and closed rooms are not sellable", () => {
    const nextRooms = rooms.map((room) => {
      return room.id === "r5" ? {...room, enabled: false} : room;
    });
    const day = project({
      rooms: nextRooms,
      calendarEntries: [{
        shopId,
        roomId: "r4",
        date: "2026-10-01",
        status: "closed",
        bookingId: "",
      }],
    }).dates.find((row) => row.date === "2026-10-01");
    assert.equal(day.total, 4);
    assert.equal(day.remaining, 3);
  });

  it("TEST 23 response has no private booking fields", () => {
    const result = project({
      bookings: assignedStays(["r1"], "confirmed"),
      calendarEntries: [{
        shopId,
        roomId: "r1",
        date: "2026-10-01",
        status: "booked",
        bookingId: "stay-confirmed-0",
        staffNote: "內部備註",
        cleaningNote: "清潔備註",
      }],
      occupancies: [{
        shopId,
        roomId: "r2",
        bookingId: "hidden",
        status: "active",
        occupancyMode: "full_day",
        startAt: stayStart,
        endAt: stayEnd,
      }],
    });
    const keys = new Set();
    collectKeys(result, keys);
    [
      "bookingId",
      "userId",
      "roomId",
      "customerName",
      "phone",
      "email",
      "petId",
      "petIds",
      "staffNote",
      "cleaningNote",
      "payment",
    ].forEach((key) => {
      assert.equal(keys.has(key), false, key);
    });
    assert.equal(keys.has("roomTypeId"), true);
    assert.equal(keys.has("remaining"), true);
  });
});
