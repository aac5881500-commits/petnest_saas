const test = require("node:test");
const assert = require("node:assert/strict");
const policy = require("./commercial_policy");
const {hasPlatformAccess} = require("../legal_pet/access");

test("舊代碼正規化後可比對，空白與大小寫視為同一個代碼", () => {
  assert.equal(policy.normalizeActivationCode(" ab-12 "), "AB12");
  assert.equal(
      policy.normalizeActivationCode("ＡＢ－１２"),
      policy.normalizeActivationCode("ab-12"),
  );
});

test("月末加一個月不是 30 天，跨年與年繳用日曆月", () => {
  assert.equal(policy.addCalendarMonths("2026-01-31", 1), "2026-02-28");
  assert.equal(policy.inclusiveServiceEnd("2026-01-31", 1), "2026-02-27");
  assert.equal(policy.inclusiveServiceEnd("2026-01-15", 1), "2026-02-14");
  assert.equal(policy.addCalendarMonths("2026-11-30", 2), "2027-01-30");
  const year = policy.nextPaidPeriod({
    today: "2026-03-01",
    months: 12,
    paidServiceUntil: "",
  });
  assert.equal(year.start, "2026-03-01");
  assert.equal(year.end, "2027-02-28");
});

test("提前續費接在目前付費結束日的次日", () => {
  const period = policy.nextPaidPeriod({
    today: "2026-03-01",
    months: 1,
    paidServiceUntil: "2026-03-20",
  });
  assert.equal(period.start, "2026-03-21");
  assert.equal(period.end, "2026-04-20");
});

test("試用與贈送只改期限，不產生收款或分潤", () => {
  const trial = policy.extendEntitlement({}, 7, "2026-03-01", "trial");
  assert.equal(trial.entitlementSource, "trial");
  assert.equal(trial.trialUntil, "2026-03-07");
  assert.equal(trial.paidServiceUntil, undefined);
  const gift = policy.extendEntitlement(
      {paidUntilDate: "2026-04-01", entitlementSource: "paid"},
      7,
      "2026-03-01",
      "gift",
  );
  assert.equal(gift.entitlementSource, "paid");
  assert.ok(gift.giftUntil);
});

test("重複確認不會再次延長，未啟用規則不算分潤", () => {
  const shop = {paidServiceUntil: "", paidUntilDate: "", originSalesRepId: "rep-a"};
  const first = policy.planPaymentConfirm({
    today: "2026-03-01",
    shop: shop,
    rules: [],
    payment: {
      id: "p1",
      status: "draft",
      cycle: "month",
      plan: "basic",
      shopId: "SHOP0001",
      amountReceivedMinor: 99900,
    },
  });
  assert.equal(first.alreadyConfirmed, false);
  assert.equal(first.commission, null);
  assert.equal(first.serviceEnd, "2026-03-31");
  const again = policy.planPaymentConfirm({
    today: "2026-03-02",
    shop: Object.assign({}, shop, first.patch),
    rules: [{id: "r", version: 1, enabled: true, mode: "percent",
      percentBps: 1000, appliesTo: "both", beneficiary: "origin",
      effectiveFrom: "2026-01-01"}],
    payment: {
      id: "p1",
      status: "confirmed",
      cycle: "month",
      plan: "basic",
      shopId: "SHOP0001",
      amountReceivedMinor: 99900,
    },
  });
  assert.equal(again.alreadyConfirmed, true);
  assert.equal(again.commission, null);
});

test("確認時留下受益業務，之後改規則或交接不改這筆分潤", () => {
  const earned = policy.planPaymentConfirm({
    today: "2026-03-01",
    shop: {
      originSalesRepId: "rep-origin",
      currentSalesRepId: "rep-current",
    },
    rules: [{
      id: "rule-1",
      version: 2,
      enabled: true,
      mode: "percent",
      percentBps: 1000,
      appliesTo: "first_payment",
      beneficiary: "origin",
      effectiveFrom: "2026-01-01",
    }],
    payment: {
      id: "pay1",
      status: "draft",
      cycle: "year",
      plan: "pro",
      shopId: "SHOP0002",
      amountReceivedMinor: 2398800,
    },
  });
  assert.equal(earned.commission.id, "pay_pay1");
  assert.equal(earned.commission.beneficiaryRepId, "rep-origin");
  assert.equal(earned.commission.ruleVersion, 2);
  assert.equal(earned.firstPayment, true);
  const renewal = policy.planPaymentConfirm({
    today: "2027-03-01",
    shop: {
      paidServiceUntil: earned.serviceEnd,
      originSalesRepId: "rep-origin",
      currentSalesRepId: "rep-new",
    },
    rules: [{
      id: "rule-9",
      version: 9,
      enabled: true,
      mode: "fixed",
      fixedMinor: 100,
      appliesTo: "renewal",
      beneficiary: "current",
      effectiveFrom: "2027-01-01",
    }],
    payment: {
      id: "pay2",
      status: "draft",
      cycle: "month",
      plan: "basic",
      shopId: "SHOP0002",
      amountReceivedMinor: 99900,
    },
  });
  assert.equal(renewal.commission.beneficiaryRepId, "rep-new");
  assert.equal(earned.commission.beneficiaryRepId, "rep-origin");
  assert.equal(renewal.firstPayment, false);
});

test("已發放分潤退款另建追回，未發放的全額退款只取消不重複扣", () => {
  const paid = policy.planCommissionRefund({
    paymentId: "pay1",
    shopId: "SHOP0001",
    ruleId: "rule-1",
    ruleVersion: 2,
    beneficiaryRepId: "rep-origin",
    amountMinor: 9990,
    baseMinor: 99900,
    clawedMinor: 0,
    mode: "percent",
    percentBps: 1000,
    status: "paid",
    accrualMonth: "2026-10",
  }, 99900, "r1", 0);
  assert.equal(paid.kind, "recovery");
  assert.equal(paid.amountMinor, 9990);
  assert.equal(paid.cancelOriginal, false);
  assert.equal(paid.id, "pay_pay1_refund_r1");
  const pending = policy.planCommissionRefund({
    paymentId: "pay1",
    status: "pending",
    mode: "percent",
    percentBps: 1000,
    amountMinor: 9990,
    baseMinor: 99900,
    clawedMinor: 0,
  }, 99900, "r1", 0);
  assert.equal(pending.cancelOriginal, true);
  assert.equal(pending.amountMinor, 0);
});

test("累計退款不能超過剩餘，部分退款按比例沖回且控制尾差", () => {
  assert.throws(() => policy.planRefund({
    receivedMinor: 99900,
    refundedMinor: 80000,
    refundMinor: 20000,
  }), /剩餘/);
  const second = policy.planRefund({
    receivedMinor: 99900,
    refundedMinor: 80000,
    refundMinor: 19900,
  });
  assert.equal(second.refundProgress, "full");
  const entry = {
    paymentId: "pay1",
    amountMinor: 10000,
    baseMinor: 99900,
    clawedMinor: 0,
    status: "settleable",
    mode: "fixed",
    fixedMinor: 10000,
  };
  const first = policy.planCommissionClawback(entry, 0, 80000, "a");
  assert.equal(first.adjustment.amountMinor, Math.round(10000 * 80000 / 99900));
  const next = policy.planCommissionClawback(Object.assign({}, entry, {
    clawedMinor: first.clawedMinor,
  }), 80000, 19900, "b");
  assert.equal(next.cancelOriginal, true);
  assert.equal(next.adjustment, null);
  assert.equal(next.clawedMinor, 10000);
  const percent = {
    paymentId: "pay1",
    amountMinor: 9990,
    baseMinor: 99900,
    clawedMinor: 0,
    status: "pending",
    openMinor: 9990,
  };
  let clawed = 0;
  let refunded = 0;
  [33300, 33300, 33300].forEach((part, index) => {
    const step = policy.planCommissionClawback(Object.assign({}, percent, {
      clawedMinor: clawed,
      status: index === 2 ? "pending" : "pending",
    }), refunded, part, `p${index}`);
    if (step.adjustment) clawed += step.adjustment.amountMinor;
    if (step.cancelOriginal) clawed = 9990;
    refunded += part;
  });
  assert.equal(clawed, 9990);
});

test("跨月發放只減少歸屬月未結清，發放月不出現負待結算", () => {
  const move = policy.planPayoutMove({
    accrualMonth: "2026-10",
    payoutMonth: "2026-11",
    openMinor: 5000,
    payoutMinor: 5000,
  });
  assert.equal(move.accrualOpenDelta, -5000);
  assert.equal(move.payoutPaidDelta, 5000);
  assert.equal(move.accrualMonth === move.payoutMonth, false);
  assert.throws(() => policy.planPayoutMove({
    accrualMonth: "2026-10",
    payoutMonth: "2026-11",
    openMinor: 5000,
    payoutMinor: 4000,
  }), /理由/);
  assert.equal(policy.canChangeCommissionStatus("cancelled", "paid"), false);
  assert.equal(policy.canChangeCommissionStatus("paid", "cancelled"), false);
  assert.equal(policy.canChangeCommissionStatus("settleable", "paid"), true);
  assert.deepEqual(policy.renewalShopDelta(true), {shops: 0, payments: 1});
});

test("舊激活碼大小寫與 expireAt 仍受期限限制，分頁不漏同排序值", () => {
  assert.equal(policy.normalizeActivationCode("ab 12"), "AB12");
  assert.ok(policy.activationCodeLookupValues("ab-12").includes("AB12"));
  assert.equal(policy.canUseActivationCode({
    enabled: true,
    maxUses: 3,
    usedCount: 0,
    type: "shop_create",
    expireAt: {seconds: Date.parse("2026-02-01T00:00:00+08:00") / 1000},
  }, "2026-03-01").ok, false);
  const fields = policy.activationSearchFields("ab-12", "宜鴻");
  assert.equal(fields.normalizedCode, "AB12");
  assert.ok(fields.nameGrams.includes("鴻"));
  const page = policy.sliceStablePage([
    {id: "a", sort: "k"},
    {id: "b", sort: "k"},
    {id: "c", sort: "k"},
  ], "a", 1);
  assert.deepEqual(page.items.map((item) => item.id), ["b"]);
  assert.equal(page.hasMore, true);
});

test("實收差異、試用後付款與不同方案提前續費", () => {
  assert.throws(() => policy.planPaymentAmounts({
    plan: "basic",
    cycle: "month",
    amountDueMinor: 99900,
    amountReceivedMinor: 80000,
    differenceReason: "",
  }), /理由/);
  const priced = policy.planPaymentAmounts({
    plan: "basic",
    cycle: "month",
    amountDueMinor: 99900,
    amountReceivedMinor: 80000,
    differenceReason: "協議折扣",
    grantFullPeriodDespiteShortfall: true,
  });
  assert.equal(priced.shortfall, true);
  const trialPay = policy.planPaymentConfirm({
    today: "2026-03-01",
    shop: {trialUntil: "2026-03-10", plan: "basic"},
    rules: [],
    payment: {
      id: "p9",
      status: "draft",
      cycle: "month",
      plan: "basic",
      shopId: "SHOP0009",
      amountReceivedMinor: 99900,
    },
  });
  assert.equal(trialPay.serviceStart, "2026-03-11");
  const switchPlan = policy.planPaymentConfirm({
    today: "2026-03-01",
    shop: {
      plan: "basic",
      paidServiceUntil: "2026-03-20",
    },
    rules: [],
    payment: {
      id: "p10",
      status: "draft",
      cycle: "month",
      plan: "pro",
      shopId: "SHOP0010",
      amountReceivedMinor: 199900,
    },
  });
  assert.equal(switchPlan.patch.plan, undefined);
  assert.equal(switchPlan.patch.nextPlan, "pro");
  assert.equal(switchPlan.serviceStart, "2026-03-21");
});

test("年繳未到期仍是付費有效，舊店只有期限時標成待確認且不改日期", () => {
  assert.equal(policy.subscriptionListStatus({
    entitlementSource: "paid",
    paidServiceUntil: "2027-02-28",
  }, "2026-06-01"), "paid_active");
  assert.equal(policy.renewalDue({
    paidServiceUntil: "2027-02-28",
  }, "2026-06-01"), false);
  assert.equal(policy.renewalDue({
    paidServiceUntil: "2026-06-20",
  }, "2026-06-01"), true);
  const legacy = policy.legacyEntitlementPatch({
    paidUntil: {seconds: 1},
    paidUntilDate: "2026-12-31",
  });
  assert.deepEqual(legacy, {entitlementSource: "legacy_unconfirmed"});
  assert.equal(policy.subscriptionListStatus({
    entitlementSource: "legacy_unconfirmed",
    paidUntilDate: "2026-12-31",
  }, "2026-06-01"), "legacy_unconfirmed");
});

test("用完、停用、過期的激活碼不能再使用", () => {
  assert.equal(policy.canUseActivationCode({
    enabled: true,
    maxUses: 1,
    usedCount: 1,
    type: "shop_create",
  }, "2026-03-01").ok, false);
  assert.equal(policy.activationStatus({
    enabled: false, maxUses: 3, usedCount: 0,
  }, "2026-03-01"), "disabled");
  assert.equal(policy.activationStatus({
    enabled: true, useByDate: "2026-02-01", maxUses: 3, usedCount: 0,
  }, "2026-03-01"), "expired");
});

test("查看業者名單不會因此取得財務或別人的業務資料", () => {
  const directoryUser = {
    uid: "staff",
    enabled: true,
    permissions: ["view_shops"],
  };
  assert.equal(
      hasPlatformAccess(directoryUser, ["manage_subscription_finance"]),
      false,
  );
  assert.equal(hasPlatformAccess(directoryUser, ["manage_sales"]), false);
  const salesUser = {
    uid: "sales",
    enabled: true,
    permissions: ["view_own_sales"],
  };
  assert.equal(
      hasPlatformAccess(salesUser, ["manage_subscription_finance"]),
      false,
  );
  assert.equal(hasPlatformAccess(salesUser, ["view_own_sales"]), true);
});

test("確認收款以 shop_commercial 快照歸屬，重試不重複計算", () => {
  const migrated = policy.salesAttribution({
    originSalesRepId: "rep-origin",
    currentSalesRepId: "rep-origin",
    shopSource: "sales",
  }, {});
  assert.equal(migrated.performanceRepId, "rep-origin");
  const handed = policy.salesAttribution({
    originSalesRepId: "rep-origin",
    currentSalesRepId: "rep-now",
  }, {
    originSalesRepId: "stale-origin",
    currentSalesRepId: "stale-current",
  });
  assert.equal(handed.originSalesRepId, "rep-origin");
  assert.equal(handed.currentSalesRepId, "rep-now");
  assert.equal(handed.performanceRepId, "rep-now");
  const confirmed = policy.planPaymentConfirm({
    today: "2026-03-01",
    shop: {
      plan: "basic",
      originSalesRepId: "stale-origin",
      currentSalesRepId: "stale-current",
    },
    attribution: handed,
    rules: [{
      id: "rule-1",
      version: 1,
      enabled: true,
      mode: "percent",
      percentBps: 1000,
      appliesTo: "both",
      beneficiary: "current",
      effectiveFrom: "2026-01-01",
    }],
    payment: {
      id: "pay-hand",
      status: "draft",
      cycle: "month",
      plan: "basic",
      shopId: "SHOP0008",
      amountReceivedMinor: 99900,
    },
  });
  assert.equal(confirmed.commission.beneficiaryRepId, "rep-now");
  assert.equal(confirmed.attribution.performanceRepId, "rep-now");
  assert.equal(policy.shouldApplyPaymentSummary(true, false), false);
  assert.equal(policy.shouldApplyPaymentSummary(false, true), false);
  assert.equal(policy.shouldApplyPaymentSummary(false, false), true);
});

test("下一期到期才改方案，再次續費不覆蓋尚未履行期間", () => {
  const shop = {
    plan: "basic",
    lockedModule: "cat_hotel",
    enabledModules: ["basic_info", "cat_hotel", "reports"],
    paidServiceUntil: "2026-04-20",
    nextPlan: "pro",
    nextPlanStarts: "2026-03-21",
  };
  assert.equal(
      policy.resolvePlanSchedule(shop, "2026-03-01").effectivePlan,
      "basic",
  );
  assert.equal(policy.materializeDuePlan(shop, "2026-03-01"), null);
  assert.deepEqual(
      policy.effectiveModules(shop, "2026-03-01"),
      ["basic_info", "cat_hotel", "reports"],
  );
  const due = policy.materializeDuePlan(shop, "2026-03-21");
  assert.equal(due.patch.plan, "pro");
  assert.ok(due.patch.enabledModules.includes("dog_hotel"));
  assert.equal(due.patch.paidServiceUntil, undefined);
  assert.equal(due.patch.nextPlan, null);
  assert.ok(policy.effectiveModules(shop, "2026-03-21").includes("store"));
  const extended = policy.planPaymentConfirm({
    today: "2026-03-05",
    shop: shop,
    rules: [],
    payment: {
      id: "pay-next",
      status: "draft",
      cycle: "month",
      plan: "basic",
      shopId: "SHOP0011",
      amountReceivedMinor: 99900,
    },
  });
  assert.equal(extended.patch.nextPlan, undefined);
  assert.equal(extended.patch.nextPlanStarts, undefined);
  assert.equal(extended.patch.followingPlan, "basic");
  assert.ok(extended.patch.paidServiceUntil > shop.paidServiceUntil);
  const queued = Object.assign({}, shop, {
    followingPlan: "basic",
    followingPlanStarts: extended.serviceStart,
  });
  assert.throws(() => policy.planPaymentConfirm({
    today: "2026-03-06",
    shop: queued,
    rules: [],
    payment: {
      id: "pay-third",
      status: "draft",
      cycle: "month",
      plan: "pro",
      shopId: "SHOP0011",
      amountReceivedMinor: 199900,
    },
  }), /尚未履行/);
});

test("激活碼同批衝突會列出，發布報表不會重複累加", () => {
  const sameBatch = policy.planActivationMigration([
    {id: "a", code: "ab-12"},
    {id: "b", code: "AB12"},
  ], {});
  assert.equal(sameBatch.updates.length, 0);
  assert.equal(sameBatch.conflicts.length, 2);
  assert.equal(sameBatch.conflicts[0].reason, "同批正規化衝突");
  const owned = policy.planActivationMigration([
    {id: "a", code: "AB12"},
    {id: "b", code: "ab12"},
  ], {AB12: "a"});
  assert.equal(owned.updates.length, 1);
  assert.equal(owned.updates[0].id, "a");
  assert.equal(owned.updates[0].bindKey, false);
  assert.equal(owned.conflicts[0].codeId, "b");
  assert.equal(policy.claimActivationKey("a", "b").ok, false);
  assert.equal(policy.claimActivationKey("", "b").ok, true);
  assert.equal(policy.claimActivationKey("b", "b").ok, true);
  const publish = policy.planSummaryPublish({
    repId: "rep-a",
    month: "2026-10",
    earnedCommissionMinor: 5000,
    openCommissionMinor: 0,
    paidCommissionMinor: 5000,
  }, false);
  assert.equal(publish.skip, false);
  assert.equal(publish.patch.earnedCommissionMinor, 5000);
  assert.equal(publish.patch.paidCommissionMinor, 5000);
  assert.equal(policy.planSummaryPublish(publish.patch, true).skip, true);
});

test("併發綁定激活碼索引時只有一筆成功", async () => {
  const keys = {};
  let lock = Promise.resolve();
  const claim = (codeId) => {
    const run = lock.then(async () => {
      const existing = keys.AB12 || "";
      const result = policy.claimActivationKey(existing, codeId);
      if (!result.ok) return result;
      keys.AB12 = codeId;
      return result;
    });
    lock = run.then(() => undefined, () => undefined);
    return run;
  };
  const results = await Promise.all([claim("code-a"), claim("code-b")]);
  const won = results.filter((item) => item.ok);
  assert.equal(won.length, 1);
  assert.equal(Object.keys(keys).length, 1);
});
