const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {calculateDaycareSurcharge} = require("./special_date_surcharge");

describe("calculateDaycareSurcharge", () => {
  const docs = [
    {
      id: "old",
      enabled: true,
      amountPerNight: 200,
      startDate: new Date("2026-09-08"),
      endDate: new Date("2026-09-10"),
      roomTypeIds: [],
    },
    {
      id: "both",
      enabled: true,
      amountPerNight: 300,
      applicableServices: ["accommodation", "daycare"],
      startDate: new Date("2026-09-08"),
      endDate: new Date("2026-09-10"),
      roomTypeIds: [],
    },
  ];

  it("does not apply old accommodation-only surcharge to daycare", () => {
    const result = calculateDaycareSurcharge(docs, {
      serviceDate: "2026-09-08",
      isRoomBased: false,
      roomTypeId: "",
    });
    assert.equal(result.total, 300);
  });

  it("adds once per daycare order", () => {
    const result = calculateDaycareSurcharge([docs[1], docs[1]], {
      serviceDate: "2026-09-08",
      isRoomBased: true,
      roomTypeId: "deluxe",
    });
    assert.equal(result.total, 600);
  });

  it("skips specified room types for independent plans", () => {
    const result = calculateDaycareSurcharge([{
      id: "typed",
      enabled: true,
      amountPerNight: 400,
      applicableServices: ["daycare"],
      startDate: new Date("2026-09-08"),
      endDate: new Date("2026-09-08"),
      roomTypeIds: ["deluxe"],
    }], {
      serviceDate: "2026-09-08",
      isRoomBased: false,
      roomTypeId: "",
    });
    assert.equal(result.total, 0);
  });
});
