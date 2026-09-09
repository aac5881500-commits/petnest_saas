const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {hasOverlappingOccupancy} = require("./daycare_occupancy");

describe("hasOverlappingOccupancy", () => {
  const start = new Date("2026-09-08T01:00:00.000Z");
  const end = new Date("2026-09-08T05:00:00.000Z");

  it("rejects two overlapping assignments on the same room", () => {
    const occupied = hasOverlappingOccupancy(
        [{
          bookingId: "a",
          status: "active",
          occupancyMode: "slot",
          startAt: start,
          endAt: end,
        }],
        start, end, "b", "slot",
    );
    assert.equal(occupied, true);
  });

  it("allows the same room on a different time range", () => {
    const occupied = hasOverlappingOccupancy(
        [{
          bookingId: "a",
          status: "active",
          occupancyMode: "slot",
          startAt: start,
          endAt: end,
        }],
        new Date("2026-09-08T06:00:00.000Z"),
        new Date("2026-09-08T08:00:00.000Z"),
        "b",
        "slot",
    );
    assert.equal(occupied, false);
  });

  it("ignores the same booking when reassigning", () => {
    const occupied = hasOverlappingOccupancy(
        [{
          bookingId: "a",
          status: "active",
          occupancyMode: "slot",
          startAt: start,
          endAt: end,
        }],
        start, end, "a", "slot",
    );
    assert.equal(occupied, false);
  });
});
