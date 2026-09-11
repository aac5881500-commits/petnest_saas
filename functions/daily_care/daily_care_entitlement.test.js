// 檔案名稱：functions/daily_care/daily_care_entitlement.test.js
// 功能說明：固定／房型／付費加購與服務日期計費

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  resolveDailyCareEntitlement,
} = require("./daily_care_entitlement");

const setting = {
  enabled: true,
  sessionCount: 1,
  stayReportMode: "included_fixed",
  sessionLabels: ["早晨", "午後", "晚間"],
  includeCheckInDay: true,
  includeCheckOutDay: false,
  stayPaidPlan: {
    name: "寵物寫真",
    price: 150,
    reports: 2,
    chargeUnit: "per_service_day",
    sessionLabels: ["上午照護", "下午照護"],
  },
};

test("固定提供基本 1 場 3 張，不按晚加購", () => {
  const result = resolveDailyCareEntitlement({
    setting,
    isDaycare: false,
    startDate: "2026-09-10",
    endDate: "2026-09-12",
  });
  assert.equal(result.entitlement.finalReports, 1);
  assert.equal(result.entitlement.finalPhotos, 3);
  assert.equal(result.amount, 0);
  assert.deepEqual(result.entitlement.serviceDates, ["2026/09/10", "2026/09/11"]);
});

test("付費每日計費依服務日期，兩天收兩次", () => {
  const result = resolveDailyCareEntitlement({
    setting: {...setting, stayReportMode: "paid_addon"},
    startDate: "2026-09-10",
    endDate: "2026-09-12",
    addonId: "stay_paid",
  });
  assert.equal(result.entitlement.finalReports, 2);
  assert.equal(result.entitlement.finalPhotos, 6);
  assert.equal(result.amount, 300);
  assert.equal(result.entitlement.chargeUnit, "per_service_day");
  assert.equal(result.entitlement.quantity, 2);
});

test("整筆收費一次，服務日期仍列出每天", () => {
  const result = resolveDailyCareEntitlement({
    setting: {
      ...setting,
      stayReportMode: "paid_addon",
      stayPaidPlan: {
        name: "寵物寫真",
        price: 400,
        reports: 1,
        chargeUnit: "once_per_stay",
      },
    },
    startDate: "2026-09-10",
    endDate: "2026-09-13",
    addonId: "stay_paid",
  });
  assert.equal(result.amount, 400);
  assert.equal(result.entitlement.quantity, 1);
  assert.equal(result.entitlement.serviceDates.length, 3);
});

test("付費模式未購買則不含顧客回報", () => {
  const result = resolveDailyCareEntitlement({
    setting: {...setting, stayReportMode: "paid_addon"},
    nights: 1,
  });
  assert.equal(result.entitlement.finalReports, 0);
  assert.equal(result.entitlement.finalPhotos, 0);
  assert.equal(result.amount, 0);
});

test("依房型 VIP 每天 2 場，未設定拋錯", () => {
  const result = resolveDailyCareEntitlement({
    setting: {
      ...setting,
      stayReportMode: "included_by_offer",
      stayOfferQuotas: {vip: {reports: 2, sessionLabels: ["上午", "下午"]}},
    },
    offerId: "vip",
    offerName: "VIP",
  });
  assert.equal(result.entitlement.baseReports, 2);
  assert.equal(result.entitlement.sessionLabels.length, 2);
  assert.throws(() => resolveDailyCareEntitlement({
    setting: {
      ...setting,
      stayReportMode: "included_by_offer",
    },
    offerId: "normal",
  }), /尚未設定/);
});
