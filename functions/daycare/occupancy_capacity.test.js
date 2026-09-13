// 檔案名稱：functions/daycare/occupancy_capacity.test.js
// 功能說明：安親可賣剩餘、未分房保留、方案模式不誤擋

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  remainingRoomsFromData,
  assertRoomTypeCapacity,
  occupiesInventory,
  NO_PHYSICAL_ROOMS,
  ROOM_TYPE_SOLD_OUT,
} = require("./daycare_occupancy");

const start = new Date("2026-09-12T02:00:00.000Z");
const end = new Date("2026-09-12T10:00:00.000Z");
const rooms = [
  {id: "r1", roomTypeId: "vip", enabled: true, status: "available", capacity: 1},
  {id: "r2", roomTypeId: "vip", enabled: true, status: "available", capacity: 1},
];

describe("remainingRoomsFromData", () => {
  it("空房顯示兩間", () => {
    const result = remainingRoomsFromData({
      rooms, bookings: [], occupancies: [], calendarEntries: [],
      holdEntries: [], roomTypeId: "vip", startAt: start, endAt: end,
    });
    assert.equal(result.remaining, 2);
    assert.equal(result.createdCount, 2);
  });

  it("沒有實體房顯示正確原因", () => {
    const result = remainingRoomsFromData({
      rooms: [], bookings: [], roomTypeId: "vip",
      startAt: start, endAt: end,
    });
    assert.equal(result.remaining, 0);
    assert.equal(result.zeroReason, NO_PHYSICAL_ROOMS);
  });

  it("住宿占用會扣實體房", () => {
    const result = remainingRoomsFromData({
      rooms, bookings: [{
        id: "stay1", status: "confirmed", bookingKind: "accommodation",
        roomId: "r1",
        startDate: new Date("2026-09-11T16:00:00.000Z"),
        endDate: new Date("2026-09-13T16:00:00.000Z"),
      }],
      roomTypeId: "vip", startAt: start, endAt: end,
    });
    assert.equal(result.remaining, 1);
  });

  it("已分房安親只扣該 roomId 一次", () => {
    const result = remainingRoomsFromData({
      rooms, bookings: [{
        id: "d1", status: "confirmed", bookingKind: "daycare",
        roomId: "r1", requestedRoomTypeId: "vip", roomTypeId: "vip",
        scheduledStartAt: start, scheduledEndAt: end,
      }],
      occupancies: [{
        bookingId: "d1", roomId: "r1", status: "active",
        occupancyMode: "slot", startAt: start, endAt: end,
      }],
      holdEntries: [],
      roomTypeId: "vip", startAt: start, endAt: end,
    });
    assert.equal(result.remaining, 1);
    assert.equal(result.reservedCount, 0);
  });

  it("未分房保留扣一間且不與已分房重複", () => {
    const result = remainingRoomsFromData({
      rooms, bookings: [{
        id: "u1", status: "pending", bookingKind: "daycare",
        roomId: "", requestedRoomTypeId: "vip",
        scheduledStartAt: start, scheduledEndAt: end,
      }, {
        id: "a1", status: "confirmed", bookingKind: "daycare",
        roomId: "r1", requestedRoomTypeId: "vip",
        scheduledStartAt: start, scheduledEndAt: end,
      }],
      holdEntries: [{
        bookingId: "u1", startAt: start.toISOString(), endAt: end.toISOString(),
      }],
      roomTypeId: "vip", startAt: start, endAt: end,
    });
    assert.equal(result.remaining, 0);
    assert.equal(result.reservedCount, 1);
  });

  it("時段不重疊不扣", () => {
    const result = remainingRoomsFromData({
      rooms: [rooms[0]], bookings: [{
        id: "d1", status: "confirmed", bookingKind: "daycare",
        roomId: "r1", scheduledStartAt: start, scheduledEndAt: end,
      }],
      roomTypeId: "vip",
      startAt: new Date("2026-09-12T11:00:00.000Z"),
      endAt: new Date("2026-09-12T13:00:00.000Z"),
    });
    assert.equal(result.remaining, 1);
  });

  it("取消後恢復空房", () => {
    const result = remainingRoomsFromData({
      rooms: [rooms[0]], bookings: [{
        id: "c1", status: "cancelled", bookingKind: "daycare",
        roomId: "r1", requestedRoomTypeId: "vip",
        scheduledStartAt: start, scheduledEndAt: end,
      }],
      holdEntries: [],
      roomTypeId: "vip", startAt: start, endAt: end,
    });
    assert.equal(result.remaining, 1);
    assert.equal(occupiesInventory({status: "cancelled"}), false);
  });

  it("同時搶最後一間，第二筆重疊保留為 0", () => {
    const first = remainingRoomsFromData({
      rooms: [rooms[0]], bookings: [], holdEntries: [],
      roomTypeId: "vip", startAt: start, endAt: end,
    });
    assert.equal(first.remaining, 1);
    const second = remainingRoomsFromData({
      rooms: [rooms[0]], bookings: [],
      holdEntries: [{
        bookingId: "winner",
        startAt: start.toISOString(),
        endAt: end.toISOString(),
      }],
      roomTypeId: "vip", startAt: start, endAt: end,
    });
    assert.equal(second.remaining, 0);
    assert.equal(second.zeroReason, ROOM_TYPE_SOLD_OUT);
  });

  it("disabled or closed rooms are unsellable", function() {
    const disabledRooms = rooms.map(function(room) {
      return Object.assign({}, room, {enabled: false});
    });
    const disabled = remainingRoomsFromData({
      rooms: disabledRooms,
      bookings: [],
      occupancies: [],
      calendarEntries: [],
      holdEntries: [],
      roomTypeId: "vip",
      startAt: start,
      endAt: end,
    });
    assert.equal(disabled.remaining, 0);
    assert.equal(disabled.usableCount, 0);
    const closedRooms = rooms.map(function(room) {
      return Object.assign({}, room, {status: "closed"});
    });
    const closed = remainingRoomsFromData({
      rooms: closedRooms,
      bookings: [],
      occupancies: [],
      calendarEntries: [],
      holdEntries: [],
      roomTypeId: "vip",
      startAt: start,
      endAt: end,
    });
    assert.equal(closed.remaining, 0);
    assert.equal(closed.usableCount, 0);
    const unavailableRooms = rooms.map(function(room) {
      return Object.assign({}, room, {status: "unavailable"});
    });
    const unavailable = remainingRoomsFromData({
      rooms: unavailableRooms,
      bookings: [],
      occupancies: [],
      calendarEntries: [],
      holdEntries: [],
      roomTypeId: "vip",
      startAt: start,
      endAt: end,
    });
    assert.equal(unavailable.remaining, 0);
  });
});

describe("assertRoomTypeCapacity", () => {
  it("方案模式沒有 requestedRoomTypeId 不誤擋", async () => {
    const result = await assertRoomTypeCapacity({}, {
      shopId: "s1",
      roomTypeId: "",
      startAt: start,
      endAt: end,
    });
    assert.equal(result.ok, true);
    assert.equal(result.remaining, 999999);
  });
});
