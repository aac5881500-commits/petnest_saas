// 檔案名稱：functions/bookings/change_booking_payment_method.test.js
// 功能說明：客戶變更付款方式欄位不得改總額與訂金期限

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assertCustomerCanChangePaymentMethod,
  buildCustomerPaymentMethodPatch,
} = require("./change_booking_payment_method");

test("僅訂單本人可改付款方式", () => {
  assert.throws(
      () => assertCustomerCanChangePaymentMethod({
        userId: "a", status: "pending",
      }, "b"),
      /僅訂單本人/,
  );
});

test("已鎖定不可改", () => {
  assert.throws(
      () => assertCustomerCanChangePaymentMethod({
        userId: "a",
        status: "checked_out",
        settlementLocked: true,
        settlementConfirmed: true,
        remainingAmount: 100,
        quotedTotalPrice: 200,
        paidAmount: 100,
      }, "a"),
      /已鎖定/,
  );
});

test("結算後待補可改補款方式", () => {
  const mode = assertCustomerCanChangePaymentMethod({
    userId: "a",
    status: "checked_out",
    settlementConfirmed: true,
    quotedTotalPrice: 3200,
    paidAmount: 1600,
  }, "a");
  assert.equal(mode, "settlement_top_up");
  const patch = buildCustomerPaymentMethodPatch({
    mode,
    paymentMethod: "atm",
    now: "t",
  });
  assert.equal(patch.settlementTopUpMethod, "atm");
  assert.equal(patch.totalPrice, undefined);
  assert.equal(patch.depositAmount, undefined);
  assert.equal(patch.depositExpireAt, undefined);
  assert.equal(patch.discountAmount, undefined);
});

test("未結算只改付款方式與金額類型", () => {
  const mode = assertCustomerCanChangePaymentMethod({
    userId: "a",
    status: "pending",
  }, "a");
  assert.equal(mode, "deposit");
  const patch = buildCustomerPaymentMethodPatch({
    mode,
    paymentMethod: "transfer",
    payAmountType: "deposit",
    now: "t",
  });
  assert.equal(patch.paymentMethod, "transfer");
  assert.equal(patch.payAmountType, "deposit");
  assert.equal(patch.depositStatus, "awaiting_proof");
  assert.equal(patch.quotedTotalPrice, undefined);
  assert.equal(patch.depositExpireAt, undefined);
});
