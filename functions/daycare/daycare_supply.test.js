// 檔案名稱：functions/daycare/daycare_supply.test.js
// 功能說明：安親耗材扣除、返還條件與幂等 ID

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  daycareSupplyDeductId,
  daycareSupplyReturnId,
  parseSupplySetting,
  buildDaycareSupplyLines,
  buildStaySupplyLines,
  shouldReturnDaycareSupplies,
  shouldSkipSupplyDeduct,
  shouldSkipSupplyReturn,
} = require("./daycare_supply");

test("舊耗材設定只套住宿，安親不扣", () => {
  const setting = parseSupplySetting({
    name: "豆腐砂",
    useInventory: true,
    inventoryItemId: "item-sand",
    quantityPerUnit: 0.5,
    deductionMode: "perRoomPerNight",
    enabled: true,
  });
  assert.equal(setting.appliesToStay, true);
  assert.equal(setting.appliesToDaycare, false);
  const booking = {nights: 2, petIds: ["a", "b"]};
  const stay = buildStaySupplyLines([setting], booking);
  assert.equal(stay.length, 1);
  assert.equal(stay[0].quantity, 1);
  assert.equal(stay[0].reason, "住宿耗材「豆腐砂」");
  assert.equal(buildDaycareSupplyLines([setting], booking).length, 0);
});

test("只套住宿時安親開始不扣", () => {
  const setting = parseSupplySetting({
    name: "濕紙巾",
    useInventory: true,
    inventoryItemId: "item-tissue",
    enabled: true,
    appliesToStay: true,
    appliesToDaycare: false,
    stayQuantityPerUnit: 1,
    stayDeductionMode: "perRoomPerStay",
    daycareQuantityPerUnit: 3,
    daycareDeductionMode: "perPetPerVisit",
  });
  const booking = {petIds: ["a", "b"]};
  assert.equal(buildDaycareSupplyLines([setting], booking).length, 0);
  assert.equal(buildStaySupplyLines([setting], booking)[0].quantity, 1);
});

test("只套安親時住宿不扣，安親依寵物數扣一次", () => {
  const setting = parseSupplySetting({
    name: "餐盒",
    useInventory: true,
    inventoryItemId: "item-meal",
    enabled: true,
    appliesToStay: false,
    appliesToDaycare: true,
    stayQuantityPerUnit: 9,
    stayDeductionMode: "perPetPerNight",
    daycareQuantityPerUnit: 1,
    daycareDeductionMode: "perPetPerVisit",
  });
  const booking = {nights: 3, petIds: ["a", "b", "c"]};
  assert.equal(buildStaySupplyLines([setting], booking).length, 0);
  const lines = buildDaycareSupplyLines([setting], booking);
  assert.equal(lines.length, 1);
  assert.equal(lines[0].quantity, 3);
  assert.equal(lines[0].reason, "安親耗材「餐盒」");
  assert.equal(lines[0].note, "開始安親扣除耗材");
});

test("同時套用時兩邊規則分開，重試使用同一個 deduct id", () => {
  const setting = parseSupplySetting({
    name: "清潔液",
    useInventory: true,
    inventoryItemId: "item-clean",
    enabled: true,
    appliesToStay: true,
    appliesToDaycare: true,
    stayQuantityPerUnit: 0.5,
    stayDeductionMode: "perRoomPerNight",
    daycareQuantityPerUnit: 1,
    daycareDeductionMode: "perRoomPerVisit",
    quantityPerUnit: 0.5,
    deductionMode: "perRoomPerNight",
  });
  const booking = {nights: 2, petIds: ["a", "b", "c", "d"]};
  assert.equal(buildStaySupplyLines([setting], booking)[0].quantity, 1);
  const daycare = buildDaycareSupplyLines([setting], booking);
  assert.equal(daycare[0].quantity, 1);
  assert.equal(daycare[0].reason, "安親耗材「清潔液」");
  const retry = buildDaycareSupplyLines([setting], booking);
  assert.equal(retry[0].quantity, daycare[0].quantity);
  const deductId = daycareSupplyDeductId("booking-1");
  assert.equal(deductId, "ds_booking-1_deduct");
  assert.equal(daycareSupplyDeductId("booking-1"), deductId);
  assert.equal(daycareSupplyReturnId("booking-1"), "ds_booking-1_return");
  assert.equal(shouldSkipSupplyDeduct(false, daycare.length), false);
  assert.equal(shouldSkipSupplyDeduct(true, daycare.length), true);
});

test("未開始不返還，已開始只返還一次，已結算不返還", () => {
  assert.equal(shouldReturnDaycareSupplies({status: "confirmed"}), false);
  assert.equal(shouldReturnDaycareSupplies({status: "pending"}), false);
  assert.equal(shouldReturnDaycareSupplies({status: "checked_in"}), true);
  assert.equal(shouldReturnDaycareSupplies({
    status: "checked_in",
    settlementConfirmed: true,
  }), false);
  assert.equal(shouldReturnDaycareSupplies({
    status: "checked_in",
    settledAt: new Date(),
  }), false);
  assert.equal(shouldReturnDaycareSupplies({status: "completed"}), false);
  assert.equal(shouldSkipSupplyReturn(false, false), true);
  assert.equal(shouldSkipSupplyReturn(false, true), false);
  assert.equal(shouldSkipSupplyReturn(true, true), true);
});

test("沒有寵物資料時仍至少以 1 隻計算", () => {
  const setting = parseSupplySetting({
    name: "毛巾",
    useInventory: true,
    inventoryItemId: "item-towel",
    enabled: true,
    appliesToDaycare: true,
    appliesToStay: false,
    daycareQuantityPerUnit: 0.5,
    daycareDeductionMode: "perPetPerVisit",
  });
  const lines = buildDaycareSupplyLines([setting], {petIds: [], pets: []});
  assert.equal(lines[0].quantity, 0.5);
});
