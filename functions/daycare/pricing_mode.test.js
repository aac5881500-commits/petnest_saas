// 檔案名稱：functions/daycare/pricing_mode.test.js
// 功能說明：安親收費模式相容值與 payload 衝突判斷

const test = require("node:test");
const assert = require("node:assert/strict");
const {isRoomBased, persistPricingMode} = require("./daycare_pricing");

test("roomType aliases are room-based and persist as roomType", () => {
  assert.equal(isRoomBased({pricingMode: "roomType"}), true);
  assert.equal(isRoomBased({pricingMode: "room_based"}), true);
  assert.equal(isRoomBased({pricingMode: "room_type"}), true);
  assert.equal(persistPricingMode({pricingMode: "room_based"}), "roomType");
});

test("independentPlan aliases are not room-based", () => {
  assert.equal(isRoomBased({pricingMode: "independentPlan"}), false);
  assert.equal(isRoomBased({pricingMode: "time_based"}), false);
  assert.equal(
      persistPricingMode({pricingMode: "time_based"}),
      "independentPlan",
  );
});

test("client independentPlan conflicts with shop roomType", () => {
  const shop = {pricingMode: "roomType"};
  const sent = {pricingMode: "independentPlan"};
  assert.equal(isRoomBased(sent) !== isRoomBased(shop), true);
});
