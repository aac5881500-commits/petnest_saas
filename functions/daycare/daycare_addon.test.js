const test = require("node:test");
const assert = require("node:assert/strict");
const {
  parseApplicableServices,
  appliesToDaycare,
  slotFullyInside,
  resolveDaycareAddonLine,
  resolveDaycareAddons,
  buildDaycareAddonDeductLines,
} = require("./daycare_addon");

test("legacy addon without applicableServices is stay only", () => {
  assert.deepEqual(parseApplicableServices(undefined), ["accommodation"]);
  assert.equal(appliesToDaycare({id: "old"}), false);
});

test("custom addon is unit price times selected pets", () => {
  const line = resolveDaycareAddonLine({
    catalogDoc: {
      customServices: [{
        id: "custom_1",
        name: "梳毛",
        price: 80,
        applicableServices: ["daycare"],
      }],
    },
    requested: {id: "custom_1", selectedPetIds: ["p1", "p2"]},
    orderPetIds: ["p1", "p2", "p3"],
    allowedAddonIds: ["custom_1"],
    startAt: new Date("2026-09-08T01:00:00.000Z"),
    endAt: new Date("2026-09-08T08:00:00.000Z"),
  });
  assert.equal(line.amount, 160);
  assert.equal(line.count, 2);
});

test("daily timed addon is pets times slots", () => {
  const line = resolveDaycareAddonLine({
    catalogDoc: {
      dailyTimedServices: [{
        id: "timed_1",
        name: "餵食",
        price: 50,
        applicableServices: ["daycare"],
        timeSlots: [
          {id: "s12", label: "12:00"},
          {id: "s14", label: "14:10"},
          {id: "s16", label: "16:20"},
        ],
      }],
    },
    requested: {
      id: "timed_1",
      selectedPetIds: ["p1", "p2"],
      selectedTimeSlots: ["s12", "s14"],
    },
    orderPetIds: ["p1", "p2"],
    allowedAddonIds: ["timed_1"],
    startAt: new Date("2026-09-08T01:00:00.000Z"),
    endAt: new Date("2026-09-08T08:00:00.000Z"),
  });
  assert.equal(line.amount, 200);
  assert.equal(line.count, 4);
});

test("slot outside window is rejected", () => {
  const start = new Date("2026-09-08T01:00:00.000Z");
  const end = new Date("2026-09-08T08:00:00.000Z");
  assert.equal(slotFullyInside("12:00", start, end), true);
  assert.equal(slotFullyInside("16:20", start, end), false);
  assert.throws(() => resolveDaycareAddonLine({
    catalogDoc: {
      dailyTimedServices: [{
        id: "timed_1",
        price: 50,
        applicableServices: ["daycare"],
        timeSlots: [{id: "s16", label: "16:20"}],
      }],
    },
    requested: {
      id: "timed_1",
      selectedPetIds: ["p1"],
      selectedTimeSlots: ["s16"],
    },
    orderPetIds: ["p1"],
    allowedAddonIds: ["timed_1"],
    startAt: start,
    endAt: end,
  }));
});

test("closed service, foreign pet and duplicate slots", () => {
  const start = new Date("2026-09-08T01:00:00.000Z");
  const end = new Date("2026-09-08T08:00:00.000Z");
  assert.throws(() => resolveDaycareAddonLine({
    catalogDoc: {
      customServices: [{id: "stay_only", price: 10}],
    },
    requested: {id: "stay_only", selectedPetIds: ["p1"]},
    orderPetIds: ["p1"],
    allowedAddonIds: ["stay_only"],
    startAt: start,
    endAt: end,
  }));
  assert.throws(() => resolveDaycareAddonLine({
    catalogDoc: {
      customServices: [{
        id: "custom_1",
        price: 80,
        applicableServices: ["daycare"],
      }],
    },
    requested: {id: "custom_1", selectedPetIds: ["other"]},
    orderPetIds: ["p1"],
    allowedAddonIds: ["custom_1"],
    startAt: start,
    endAt: end,
  }));
  const deduped = resolveDaycareAddonLine({
    catalogDoc: {
      dailyTimedServices: [{
        id: "timed_1",
        price: 50,
        applicableServices: ["daycare"],
        timeSlots: [{id: "s12", label: "12:00"}],
      }],
    },
    requested: {
      id: "timed_1",
      selectedPetIds: ["p1"],
      selectedTimeSlots: ["s12", "s12", "12:00"],
    },
    orderPetIds: ["p1"],
    allowedAddonIds: ["timed_1"],
    startAt: start,
    endAt: end,
  });
  assert.equal(deduped.count, 1);
});

test("inventory deduct uses final quantity", () => {
  const {addonSnapshot} = resolveDaycareAddons({
    catalogDoc: {
      customServices: [{
        id: "custom_1",
        name: "梳毛",
        price: 10,
        applicableServices: ["daycare"],
        useInventory: true,
        inventoryBindings: [{inventoryItemId: "inv1", quantityPerUnit: 1}],
      }],
    },
    requestedAddons: [{id: "custom_1", selectedPetIds: ["a", "b"]}],
    orderPetIds: ["a", "b"],
    allowedAddonIds: ["custom_1"],
    startAt: new Date("2026-09-08T01:00:00.000Z"),
    endAt: new Date("2026-09-08T08:00:00.000Z"),
  });
  const lines = buildDaycareAddonDeductLines(addonSnapshot, {
    customServices: [{
      id: "custom_1",
      useInventory: true,
      inventoryBindings: [{inventoryItemId: "inv1", quantityPerUnit: 1}],
    }],
  });
  assert.equal(lines[0].quantity, 2);
});
