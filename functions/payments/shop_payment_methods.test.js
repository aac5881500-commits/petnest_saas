// 檔案名稱：functions/payments/shop_payment_methods.test.js
// 功能說明：收款方式有效性與至少保留一種

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  effectiveMethodIds,
  validateOperationSettings,
  isCustomerMethodAvailable,
} = require("./shop_payment_methods");

/**
 * @param {Object=} overrides
 * @return {Object}
 */
function shop(overrides = {}) {
  return {
    bankName: "台灣銀行",
    accountName: "毛孩旅館",
    accountNumber: "123456789",
    paymentSetting: {
      reviewStatus: "approved",
      creditCardEnabled: true,
      atmEnabled: true,
      cvsCodeEnabled: true,
      enabledMethods: {creditCard: true, atm: true, cvsCode: true},
      operationSettings: {
        cashPaymentEnabled: true,
        bankTransferEnabled: true,
        ecpayEnabled: true,
        creditCardEnabled: true,
        atmEnabled: true,
        cvsCodeEnabled: true,
      },
    },
    ...overrides,
  };
}

test("missing cash flag defaults to enabled", () => {
  const data = shop();
  delete data.paymentSetting.operationSettings.cashPaymentEnabled;
  assert.ok(effectiveMethodIds(data).includes("cash"));
});

test("ecpay on with all children off is not a usable method", () => {
  const data = shop();
  data.paymentSetting.operationSettings.creditCardEnabled = false;
  data.paymentSetting.operationSettings.atmEnabled = false;
  data.paymentSetting.operationSettings.cvsCodeEnabled = false;
  data.paymentSetting.operationSettings.cashPaymentEnabled = false;
  data.paymentSetting.operationSettings.bankTransferEnabled = false;
  assert.deepEqual(effectiveMethodIds(data), []);
});

test("incomplete bank account is not usable", () => {
  const data = shop({bankName: "", accountName: "", accountNumber: ""});
  assert.equal(effectiveMethodIds(data).includes("transfer"), false);
  const result = validateOperationSettings({
    shop: data,
    cashPaymentEnabled: false,
    bankTransferEnabled: true,
    ecpayEnabled: false,
    creditCardEnabled: false,
    atmEnabled: false,
    cvsCodeEnabled: false,
  });
  assert.equal(result.ok, false);
});

test("last method cannot be turned off", () => {
  const result = validateOperationSettings({
    shop: shop({bankName: "", accountName: "", accountNumber: ""}),
    cashPaymentEnabled: false,
    bankTransferEnabled: false,
    ecpayEnabled: false,
    creditCardEnabled: false,
    atmEnabled: false,
    cvsCodeEnabled: false,
  });
  assert.equal(result.ok, false);
  assert.equal(result.message, "請至少保留一種收款方式。");
});

test("customer method check follows operation settings", () => {
  const data = shop();
  data.paymentSetting.operationSettings.creditCardEnabled = false;
  assert.equal(isCustomerMethodAvailable(data, "credit_card"), false);
  assert.equal(isCustomerMethodAvailable(data, "cash"), true);
});
