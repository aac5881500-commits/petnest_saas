// 檔案名稱：functions/daily_care/daily_care_entitlement.test.js
// 功能說明：固定／房型／付費加購與服務日期計費

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  resolveDailyCareEntitlement,
  applyAuthoritativeCare,
  daycareByOfferBlocked,
  validateDailyCareSession,
  entitlementSessionCount,
  pickEntitlementSnapshot,
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

test("同日入住退房為 0 天且舊開關不影響新訂單", () => {
  const result = resolveDailyCareEntitlement({
    setting: {
      ...setting,
      includeCheckInDay: false,
      includeCheckOutDay: true,
    },
    startDate: "2026-09-16",
    endDate: "2026-09-16",
  });
  assert.deepEqual(result.entitlement.serviceDates, []);
});

test("住宿 9/16 至 9/18 固定兩天，即使舊設定要含退房日", () => {
  const result = resolveDailyCareEntitlement({
    setting: {
      ...setting,
      includeCheckOutDay: true,
    },
    startDate: "2026-09-16",
    endDate: "2026-09-18",
  });
  assert.deepEqual(
      result.entitlement.serviceDates,
      ["2026/09/16", "2026/09/17"],
  );
});

test("安親只使用服務當日", () => {
  const result = resolveDailyCareEntitlement({
    setting: {...setting, daycareEnabled: true, daycareSessionCount: 1},
    isDaycare: true,
    startDate: "2026-09-16",
    endDate: "2026-09-18",
  });
  assert.deepEqual(result.entitlement.serviceDates, ["2026/09/16"]);
});

function stayDates(startDate, endDate) {
  return resolveDailyCareEntitlement({
    setting,
    startDate,
    endDate,
  }).entitlement.serviceDates;
}

test("純日期字串不經 UTC 位移", () => {
  assert.deepEqual(
      stayDates("2026-09-28", "2026-09-30"),
      ["2026/09/28", "2026/09/29"],
  );
  assert.deepEqual(
      stayDates("2026/09/28", "2026/09/30"),
      ["2026/09/28", "2026/09/29"],
  );
});

test("台北午夜與等效 UTC 都落在台灣 9/28", () => {
  const end = "2026-09-30T00:00:00+08:00";
  assert.deepEqual(
      stayDates("2026-09-28T00:00:00+08:00", end),
      ["2026/09/28", "2026/09/29"],
  );
  assert.deepEqual(
      stayDates("2026-09-27T16:00:00Z", "2026-09-29T16:00:00Z"),
      ["2026/09/28", "2026/09/29"],
  );
  assert.deepEqual(
      stayDates(new Date("2026-09-28T00:00:00+08:00"), new Date(end)),
      ["2026/09/28", "2026/09/29"],
  );
  const timestampLike = {
    toDate() {
      return new Date("2026-09-28T00:00:00+08:00");
    },
  };
  const endTimestamp = {
    seconds: Math.floor(new Date("2026-09-30T00:00:00+08:00").getTime() / 1000),
  };
  assert.deepEqual(
      stayDates(timestampLike, endTimestamp),
      ["2026/09/28", "2026/09/29"],
  );
});

test("跨月與跨年仍包含入住日、不含退房日", () => {
  assert.deepEqual(
      stayDates("2026-01-31", "2026-02-02"),
      ["2026/01/31", "2026/02/01"],
  );
  assert.deepEqual(
      stayDates("2026-12-31", "2027-01-02"),
      ["2026/12/31", "2027/01/01"],
  );
});

test("安親服務時間轉成台灣當日", () => {
  const result = resolveDailyCareEntitlement({
    setting: {...setting, daycareEnabled: true},
    isDaycare: true,
    startDate: "2026-09-27T16:00:00Z",
  });
  assert.deepEqual(result.entitlement.serviceDates, ["2026/09/28"]);
});

test("付費模式任意加購 ID 不算已購買", () => {
  const result = resolveDailyCareEntitlement({
    setting: {...setting, stayReportMode: "paid_addon"},
    startDate: "2026-09-28",
    endDate: "2026-09-30",
    addonId: "forged-plan",
  });
  assert.equal(result.entitlement.finalReports, 0);
  assert.equal(result.amount, 0);
  assert.equal(result.addonLine, null);
});

test("後端金額取代客戶端照護加購，不採用客戶權益", () => {
  const quoted = resolveDailyCareEntitlement({
    setting: {...setting, stayReportMode: "paid_addon"},
    startDate: "2026-09-28",
    endDate: "2026-09-30",
    addonId: "stay_paid",
  });
  const selected = applyAuthoritativeCare({
    addons: [
      {id: "towel", type: "service", amount: 50},
      {id: "stay_paid", type: "daily_care", amount: 999, name: "偽造"},
    ],
    payableAfterCoupon: 1200,
    quoted,
  });
  assert.equal(selected.payableAfterCoupon, 1200 - 999 + quoted.amount);
  assert.equal(selected.addons.length, 2);
  assert.equal(selected.addons[1].amount, quoted.amount);
  assert.equal(selected.entitlement.finalReports, quoted.entitlement.finalReports);
  const forged = {enabled: true, finalReports: 3, sessionLabels: ["甲", "乙", "丙"], mode: "paid_addon"};
  assert.notEqual(
      pickEntitlementSnapshot(forged, quoted.entitlement).finalReports,
      quoted.entitlement.finalReports,
  );
  const cleared = applyAuthoritativeCare({
    addons: [{id: "stay_paid", type: "daily_care", amount: 300}],
    payableAfterCoupon: 1000,
    quoted: resolveDailyCareEntitlement({
      setting: {...setting, stayReportMode: "paid_addon"},
      startDate: "2026-09-28",
      endDate: "2026-09-30",
    }),
  });
  assert.equal(cleared.amount, 0);
  assert.equal(cleared.addons.length, 0);
  assert.equal(cleared.entitlement.finalReports, 0);
  assert.equal(cleared.payableAfterCoupon, 700);
});

test("獨立方案不可接受依房型提供", () => {
  assert.equal(daycareByOfferBlocked({
    daycareEnabled: true,
    daycareReportMode: "included_by_offer",
  }, false), true);
  assert.equal(daycareByOfferBlocked({
    daycareEnabled: true,
    daycareReportMode: "included_by_offer",
  }, true), false);
  assert.equal(daycareByOfferBlocked({
    daycareEnabled: false,
    daycareReportMode: "included_by_offer",
  }, false), false);
  assert.equal(daycareByOfferBlocked({
    daycareEnabled: true,
    daycareReportMode: "paid_addon",
  }, false), false);
});

test("finalReports=0 拒絕上傳與完成，並檢查日期場次", () => {
  const booking = {
    shopId: "shop-1",
    roomId: "room-1",
    bookingKind: "accommodation",
    startDate: "2026-09-28T00:00:00+08:00",
    endDate: "2026-09-30T00:00:00+08:00",
    dailyCareEntitlement: {enabled: true, finalReports: 0},
  };
  assert.equal(entitlementSessionCount(booking), 0);
  assert.equal(validateDailyCareSession(booking, {
    shopId: "shop-1",
    roomId: "room-1",
    sessionIndex: 0,
    recordDate: "2026-09-28",
  }).ok, false);
  const entitled = {
    ...booking,
    dailyCareEntitlement: {enabled: true, finalReports: 1},
  };
  assert.equal(validateDailyCareSession(entitled, {
    shopId: "shop-1",
    roomId: "room-1",
    sessionIndex: 0,
    recordDate: "2026-09-28",
  }).ok, true);
  assert.equal(validateDailyCareSession(entitled, {
    shopId: "shop-1",
    roomId: "room-1",
    sessionIndex: 1,
    recordDate: "2026-09-28",
  }).ok, false);
  assert.equal(validateDailyCareSession(entitled, {
    shopId: "shop-1",
    roomId: "room-1",
    sessionIndex: 0,
    recordDate: "2026-09-30",
  }).ok, false);
  assert.equal(validateDailyCareSession(entitled, {
    shopId: "other",
    roomId: "room-1",
    sessionIndex: 0,
    recordDate: "2026-09-28",
  }).message, "訂單不屬於這家店");
  assert.equal(validateDailyCareSession(entitled, {
    shopId: "shop-1",
    roomId: "room-2",
    sessionIndex: 0,
    recordDate: "2026-09-28",
  }).message, "房間與訂單不一致");
});
