/**
 * 業務歸屬、激活碼、訂閱期間與分潤的純規則。
 * 金額用整數最小單位（新台幣分）。日期用 Asia/Taipei 的 YYYY-MM-DD。
 */

const TAIPEI_OFFSET_MS = 8 * 60 * 60 * 1000;

const PLAN_PRICES = {
  basic: {month: 99900, year: 99900 * 12},
  pro: {month: 199900, year: 199900 * 12},
};

const SOURCES = ["platform_direct", "sales", "campaign", "other"];

/**
 * @param {Date|number|string} value
 * @return {string}
 */
function taipeiDateKey(value) {
  const date = value instanceof Date ? value : new Date(value);
  const shifted = new Date(date.getTime() + TAIPEI_OFFSET_MS);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const d = String(shifted.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * @param {string} code
 * @return {string}
 */
function normalizeActivationCode(code) {
  return String(code || "")
      .normalize("NFKC")
      .replace(/[\s-]+/g, "")
      .toUpperCase();
}

/**
 * @param {string} dateKey
 * @param {number} months
 * @return {string} 同日；該月沒有此日時用該月最後一天。
 */
function addCalendarMonths(dateKey, months) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateKey || "");
  if (!match) {
    throw new Error("日期格式須為 YYYY-MM-DD");
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const total = (year * 12 + (month - 1)) + months;
  const nextYear = Math.floor(total / 12);
  const nextMonth = total % 12;
  const lastDay = new Date(Date.UTC(nextYear, nextMonth + 1, 0)).getUTCDate();
  const nextDay = Math.min(day, lastDay);
  const mm = String(nextMonth + 1).padStart(2, "0");
  const dd = String(nextDay).padStart(2, "0");
  return `${nextYear}-${mm}-${dd}`;
}

/**
 * @param {string} dateKey
 * @param {number} days
 * @return {string}
 */
function addDays(dateKey, days) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateKey || "");
  if (!match) {
    throw new Error("日期格式須為 YYYY-MM-DD");
  }
  const utc = Date.UTC(
      Number(match[1]), Number(match[2]) - 1, Number(match[3]),
  );
  const next = new Date(utc + days * 24 * 60 * 60 * 1000);
  const y = next.getUTCFullYear();
  const m = String(next.getUTCMonth() + 1).padStart(2, "0");
  const d = String(next.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * 含首日的服務結束日。一個月不是 30 天。
 * 2026-01-31 加一個月，結束日是 2026-02-27（次期從 2026-02-28 起）。
 * @param {string} startDate
 * @param {number} months
 * @return {string}
 */
function inclusiveServiceEnd(startDate, months) {
  return addDays(addCalendarMonths(startDate, months), -1);
}

/**
 * 提前續費接在目前付費結束日的次日，不重疊、不縮短。
 * @param {Object} input
 * @return {{start: string, end: string}}
 */
function nextPaidPeriod(input) {
  const today = input.today;
  const months = input.months;
  const currentEnd = input.paidServiceUntil || "";
  const start = currentEnd && currentEnd >= today ?
    addDays(currentEnd, 1) :
    today;
  return {start: start, end: inclusiveServiceEnd(start, months)};
}

/**
 * @param {string} left
 * @param {string} right
 * @return {string}
 */
function laterDate(left, right) {
  if (!left) return right || "";
  if (!right) return left;
  return left > right ? left : right;
}

/**
 * @param {string} plan
 * @param {string} cycle month|year
 * @return {number}
 */
function catalogAmount(plan, cycle) {
  const price = PLAN_PRICES[plan];
  if (!price || (cycle !== "month" && cycle !== "year")) {
    throw new Error("方案或週期不正確");
  }
  return cycle === "year" ? price.year : price.month;
}

/**
 * @param {Object} code
 * @param {string} today
 * @return {{ok: boolean, reason: string}}
 */
function canUseActivationCode(code, today) {
  if (!code || code.enabled === false) {
    return {ok: false, reason: "激活碼已停用"};
  }
  if (code.type && code.type !== "shop_create") {
    return {ok: false, reason: "此激活碼不能用來開店"};
  }
  const maxUses = Number(code.maxUses || 0);
  const used = Number(code.usedCount || 0);
  if (maxUses > 0 && used >= maxUses) {
    return {ok: false, reason: "激活碼已用完"};
  }
  const deadline = effectiveUseByDate(code);
  if (deadline && today > deadline) {
    return {ok: false, reason: "激活碼已超過使用期限"};
  }
  return {ok: true, reason: ""};
}

/**
 * @param {Object} code 激活碼
 * @param {string} today 台北今天
 * @return {string}
 */
function activationStatus(code, today) {
  if (!code || code.enabled === false) return "disabled";
  const deadline = effectiveUseByDate(code);
  if (deadline && today > deadline) return "expired";
  const maxUses = Number(code.maxUses || 0);
  if (maxUses > 0 && Number(code.usedCount || 0) >= maxUses) {
    return "exhausted";
  }
  return "active";
}

/**
 * @param {Object} code
 * @return {Object}
 */
function activationSourceSnapshot(code) {
  const salesRepId = String(code.salesRepId || "");
  let source = String(code.shopSource || "");
  if (!SOURCES.includes(source)) {
    source = salesRepId ? "sales" : "platform_direct";
  }
  return {
    activationCodeId: String(code.id || ""),
    code: String(code.code || ""),
    normalizedCode: normalizeActivationCode(code.code),
    salesRepId: salesRepId,
    campaignName: String(code.campaignName || ""),
    shopSource: source,
    freeDays: Math.max(0, Number(code.freeDays || 0)),
    plan: String(code.plan || "free"),
    module: String(code.module || "cat_hotel"),
  };
}

/**
 * 試用與贈送只延長可用期限，不產生收款與分潤。
 * @param {Object} shop
 * @param {number} days
 * @param {string} today
 * @param {string} kind trial|gift
 * @return {Object}
 */
function extendEntitlement(shop, days, today, kind) {
  const current = String(shop.paidUntilDate || "");
  const base = current && current >= today ? addDays(current, 1) : today;
  const end = addDays(base, Math.max(0, days) - 1);
  const paidUntilDate = laterDate(current, end);
  const patch = {
    paidUntilDate: paidUntilDate,
    entitlementSource: shop.entitlementSource === "paid" ? "paid" : kind,
  };
  if (kind === "trial") patch.trialUntil = laterDate(shop.trialUntil, end);
  if (kind === "gift") patch.giftUntil = laterDate(shop.giftUntil, end);
  return patch;
}

/**
 * @param {Object} input
 * @return {Object}
 */
function planPaymentConfirm(input) {
  const payment = input.payment || {};
  if (payment.status === "confirmed") {
    return {alreadyConfirmed: true, patch: {}, commission: null};
  }
  if (payment.status === "void" || payment.status === "refunded") {
    throw new Error("這筆收款已作廢或退款，不能再確認");
  }
  const shop = input.shop || {};
  const months = payment.cycle === "year" ? 12 : 1;
  const period = previewPaidPeriod(shop, input.today, months);
  const hadPaid = Boolean(shop.paidServiceUntil);
  const amount = Number(payment.amountReceivedMinor || 0);
  const attribution = input.attribution || salesAttribution(null, shop);
  const schedule = resolvePlanSchedule(shop, input.today);
  const currentPlan = schedule.effectivePlan;
  if (shop.paidServiceUntil && period.end < shop.paidServiceUntil) {
    throw new Error("新的付費期間不能覆蓋尚未結束的服務");
  }
  if (schedule.followingPlan && payment.plan !== schedule.followingPlan) {
    throw new Error("已有尚未生效的方案，不能覆蓋尚未履行的付費期間");
  }
  const patch = {
    paidServiceUntil: period.end,
    paidUntilDate: laterDate(shop.paidUntilDate, period.end),
    entitlementSource: "paid",
    lastSubscriptionPaymentId: payment.id,
  };
  const queuedSame = schedule.nextPlan && payment.plan === schedule.nextPlan;
  const switchingLater = currentPlan && currentPlan !== payment.plan &&
    period.start > input.today;
  if (schedule.nextPlan && !queuedSame && !schedule.followingPlan) {
    patch.followingPlan = payment.plan;
    patch.followingPlanStarts = period.start;
  } else if (!schedule.nextPlan && switchingLater) {
    patch.nextPlan = payment.plan;
    patch.nextPlanStarts = period.start;
  } else if (!schedule.nextPlan && !switchingLater) {
    patch.plan = payment.plan;
    patch.enabledModules = planModules(
        payment.plan,
        shop.lockedModule || shop.businessType,
        shop.enabledModules,
    );
    patch.nextPlan = null;
    patch.nextPlanStarts = null;
    patch.followingPlan = null;
    patch.followingPlanStarts = null;
  }
  const rule = pickCommissionRule(input.rules || [], {
    today: input.today,
    firstPayment: !hadPaid,
  });
  let commission = null;
  if (rule && amount > 0) {
    const repId = rule.beneficiary === "current" ?
      attribution.currentSalesRepId :
      attribution.originSalesRepId;
    if (repId) {
      commission = {
        id: `pay_${payment.id}`,
        paymentId: payment.id,
        shopId: payment.shopId,
        ruleId: rule.id,
        ruleVersion: rule.version,
        beneficiaryRepId: repId,
        amountMinor: commissionAmount(rule, amount),
        baseMinor: amount,
        mode: rule.mode,
        percentBps: Number(rule.percentBps || 0),
        fixedMinor: Number(rule.fixedMinor || 0),
        refundRule: "proportional",
        clawedMinor: 0,
        openMinor: commissionAmount(rule, amount),
        accrualMonth: String(input.today || "").slice(0, 7),
        status: "pending",
        kind: "earn",
      };
    }
  }
  return {
    alreadyConfirmed: false,
    serviceStart: period.start,
    serviceEnd: period.end,
    firstPayment: !hadPaid,
    patch: patch,
    commission: commission,
    summaryDelta: {
      collectedMinor: amount,
      firstPaid: !hadPaid ? 1 : 0,
      renewal: hadPaid ? 1 : 0,
    },
    deferredStart: period.start > input.today,
    attribution: attribution,
  };
}

/**
 * @param {Array<Object>} rules
 * @param {{today: string, firstPayment: boolean}} context
 * @return {Object|null}
 */
function pickCommissionRule(rules, context) {
  const matches = (rules || []).filter((rule) => {
    if (!rule || rule.enabled !== true) return false;
    if (rule.effectiveFrom && context.today < rule.effectiveFrom) return false;
    if (rule.effectiveUntil && context.today > rule.effectiveUntil) {
      return false;
    }
    if (rule.appliesTo === "first_payment" && !context.firstPayment) {
      return false;
    }
    if (rule.appliesTo === "renewal" && context.firstPayment) return false;
    return true;
  });
  matches.sort((a, b) => {
    const from = String(b.effectiveFrom || "")
        .localeCompare(String(a.effectiveFrom || ""));
    if (from) return from;
    const version = Number(b.version || 0) - Number(a.version || 0);
    if (version) return version;
    return String(a.id || "").localeCompare(String(b.id || ""));
  });
  return matches[0] || null;
}

/**
 * @param {Object} rule
 * @param {number} amountMinor
 * @return {number}
 */
function commissionAmount(rule, amountMinor) {
  if (rule.mode === "fixed") {
    return Math.max(0, Math.round(Number(rule.fixedMinor || 0)));
  }
  const bps = Math.max(0, Number(rule.percentBps || 0));
  return Math.round(amountMinor * bps / 10000);
}

/**
 * 已發放不改寫。退款另建負向調整。
 * @param {Object} entry
 * @param {number} refundMinor
 * @param {string} refundId
 * @param {number} refundedBefore 這次之前已退金額
 * @return {Object|null}
 */
function planCommissionRefund(entry, refundMinor, refundId, refundedBefore) {
  const before = Number(refundedBefore || 0);
  const planned = planCommissionClawback(entry, before, refundMinor, refundId);
  if (!planned || (!planned.adjustment && !planned.cancelOriginal)) return null;
  return planned.adjustment ? Object.assign({
    cancelOriginal: planned.cancelOriginal,
    clawedMinor: planned.clawedMinor,
    openMinor: planned.openMinor,
  }, planned.adjustment) : {
    cancelOriginal: true,
    clawedMinor: planned.clawedMinor,
    openMinor: 0,
    amountMinor: 0,
  };
}

/**
 * @param {Object} shop
 * @param {string} today
 * @return {string}
 */
function subscriptionListStatus(shop, today) {
  if (shop.entitlementSource === "legacy_unconfirmed") {
    return "legacy_unconfirmed";
  }
  const paidEnd = String(shop.paidServiceUntil || "");
  const trialEnd = String(shop.trialUntil || "");
  const entitlement = String(shop.paidUntilDate || "");
  if (paidEnd && paidEnd >= today) return "paid_active";
  if (shop.entitlementSource === "trial" && trialEnd >= today) return "trial";
  if (entitlement && entitlement >= today &&
      shop.entitlementSource === "gift") {
    return "gift";
  }
  if ((paidEnd && paidEnd < today) ||
      (entitlement && entitlement < today)) {
    return "expired";
  }
  return "none";
}

/**
 * 即將到期：付費結束日在 30 個日曆天內，且尚未有更後面的付費期間。
 * 未到期不代表下一期已續約。
 * @param {Object} shop
 * @param {string} today
 * @return {boolean}
 */
function renewalDue(shop, today) {
  const end = String(shop.paidServiceUntil || "");
  if (!end || end < today) return false;
  return end <= addDays(today, 30);
}

/**
 * @param {Object} shop
 * @return {Object}
 */
function legacyEntitlementPatch(shop) {
  if (shop.entitlementSource) return {};
  if (!shop.paidUntil && !shop.paidUntilDate) return {};
  return {entitlementSource: "legacy_unconfirmed"};
}

/**
 * 舊 expireAt 與新 useByDate 都視為使用截止日。
 * @param {Object} code 激活碼
 * @return {string}
 */
function effectiveUseByDate(code) {
  const row = code || {};
  if (/^\d{4}-\d{2}-\d{2}$/.test(String(row.useByDate || ""))) {
    return String(row.useByDate);
  }
  const expireAt = row.expireAt;
  if (!expireAt) return "";
  if (/^\d{4}-\d{2}-\d{2}$/.test(String(expireAt))) return String(expireAt);
  if (expireAt.toDate) return taipeiDateKey(expireAt.toDate());
  if (expireAt.seconds) {
    return taipeiDateKey(new Date(expireAt.seconds * 1000));
  }
  return "";
}

/**
 * @param {string} raw 使用者輸入
 * @return {string[]}
 */
function activationCodeLookupValues(raw) {
  const trimmed = String(raw || "").trim();
  const normalized = normalizeActivationCode(trimmed);
  const values = [
    trimmed,
    trimmed.toUpperCase(),
    trimmed.toLowerCase(),
    normalized,
  ];
  const unique = [];
  values.forEach((value) => {
    if (value && unique.indexOf(value) < 0) unique.push(value);
  });
  return unique;
}

/**
 * @param {string} code 代碼
 * @param {string} name 名稱
 * @return {Object}
 */
function activationSearchFields(code, name) {
  const normalizedCode = normalizeActivationCode(code);
  const nameNorm = String(name || "")
      .normalize("NFKC")
      .toLowerCase()
      .replace(/\s+/g, "")
      .slice(0, 32);
  const nameGrams = [];
  for (let size = 1; size <= 4; size++) {
    for (let index = 0; index + size <= nameNorm.length; index++) {
      nameGrams.push(nameNorm.slice(index, index + size));
      if (nameGrams.length >= 80) break;
    }
    if (nameGrams.length >= 80) break;
  }
  const codePrefixes = [];
  const prefixLength = Math.min(normalizedCode.length, 16);
  for (let length = 1; length <= prefixLength; length++) {
    codePrefixes.push(normalizedCode.slice(0, length));
  }
  return {
    normalizedCode: normalizedCode,
    nameNorm: nameNorm,
    nameGrams: Array.from(new Set(nameGrams)),
    codePrefixes: codePrefixes,
  };
}

/**
 * @param {string} query 搜尋詞
 * @return {string}
 */
function activationNameGram(query) {
  const text = String(query || "")
      .normalize("NFKC")
      .toLowerCase()
      .replace(/\s+/g, "");
  if (!text) return "";
  if (text.length <= 4) return text;
  const start = Math.floor((text.length - 4) / 2);
  return text.slice(start, start + 4);
}

/**
 * 付費期間接在尚未用完的付費、試用或贈送之後，避免重疊吃掉免費天數。
 * @param {Object} shop 店家
 * @param {string} today 今天
 * @param {number} months 月數
 * @return {{start: string, end: string}}
 */
function previewPaidPeriod(shop, today, months) {
  const anchors = [];
  ["paidServiceUntil", "trialUntil", "giftUntil"].forEach((key) => {
    const value = String((shop || {})[key] || "");
    if (value && value >= today) anchors.push(value);
  });
  anchors.sort();
  const anchor = anchors.length ? anchors[anchors.length - 1] : "";
  const start = anchor ? addDays(anchor, 1) : today;
  return {start: start, end: inclusiveServiceEnd(start, months)};
}

/**
 * @param {*} value 金額
 * @param {string} label 欄位
 * @return {number}
 */
function safeMinor(value, label) {
  const amount = Number(value);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw new Error(`${label}必須是零或正整數`);
  }
  if (amount > 100000000) {
    throw new Error(`${label}超出可登記範圍`);
  }
  return amount;
}

/**
 * @param {Object} input 報價
 * @return {Object}
 */
function planPaymentAmounts(input) {
  const standard = catalogAmount(input.plan, input.cycle);
  const due = safeMinor(input.amountDueMinor, "應收金額");
  const received = safeMinor(input.amountReceivedMinor, "實收金額");
  if (due < 1 || received < 1) {
    throw new Error("零元請用贈送或試用，不算付費");
  }
  const reason = String(input.differenceReason || "").trim();
  if ((due !== standard || received !== due) && reason.length < 2) {
    throw new Error("金額與標準價或應收不同時，必須填寫理由");
  }
  if (received < due && input.grantFullPeriodDespiteShortfall !== true) {
    throw new Error("實收不足應收時，需明確確認仍授予完整期間");
  }
  return {
    standardPriceMinor: standard,
    amountDueMinor: due,
    amountReceivedMinor: received,
    shortfall: received < due,
  };
}

/**
 * @param {Object} input 原收款與本次退款
 * @return {Object}
 */
function planRefund(input) {
  const received = safeMinor(input.receivedMinor, "實收金額");
  const already = safeMinor(input.refundedMinor || 0, "已退金額");
  const refund = Number(input.refundMinor);
  if (!Number.isSafeInteger(refund) || refund < 1) {
    throw new Error("退款金額必須是正整數");
  }
  if (already > received) {
    return {
      anomaly: true,
      reason: "累計退款已超過實收，不自動改歷史收款",
    };
  }
  if (refund > received - already) {
    throw new Error("退款不能超過剩餘可退金額");
  }
  const next = already + refund;
  return {
    anomaly: false,
    refundedMinor: next,
    refundProgress: next === received ? "full" : "partial",
    remainingMinor: received - next,
  };
}

/**
 * 累計退款比例決定應沖回，本次只扣新增的差額。
 * @param {Object} entry 原分潤
 * @param {number} refundedBefore 退款前累計
 * @param {number} refundMinor 本次退款
 * @param {string} refundId 退款編號
 * @return {Object}
 */
function planCommissionClawback(entry, refundedBefore, refundMinor, refundId) {
  const row = entry || {};
  const base = Number(row.baseMinor || 0);
  const original = Number(row.amountMinor || 0);
  const already = Number(row.clawedMinor || 0);
  const nextRefunded = Number(refundedBefore || 0) + Number(refundMinor || 0);
  const capped = Math.min(Math.max(0, nextRefunded), base);
  const target = base > 0 ?
    Math.min(original, Math.round(original * capped / base)) : 0;
  const delta = Math.max(0, Math.min(original - already, target - already));
  const full = base > 0 && nextRefunded >= base;
  const unpaid = row.status === "pending" || row.status === "settleable";
  if (full && unpaid) {
    return {
      cancelOriginal: true,
      adjustment: null,
      clawedMinor: original,
      openMinor: 0,
    };
  }
  if (!delta) {
    return {
      cancelOriginal: false,
      adjustment: null,
      clawedMinor: already,
      openMinor: Number(row.openMinor || 0),
    };
  }
  const paid = row.status === "paid";
  return {
    cancelOriginal: false,
    clawedMinor: already + delta,
    openMinor: paid ? 0 : Math.max(0, original - already - delta),
    adjustment: {
      id: `pay_${row.paymentId}_refund_${refundId}`,
      paymentId: row.paymentId,
      shopId: row.shopId,
      ruleId: row.ruleId,
      ruleVersion: row.ruleVersion,
      beneficiaryRepId: row.beneficiaryRepId,
      accrualMonth: row.accrualMonth || "",
      amountMinor: delta,
      status: paid ? "recovery" : "pending",
      kind: paid ? "recovery" : "refund_adjust",
    },
  };
}

/**
 * 發放月只記實發。未結清從歸屬月減少，不在發放月出現負待結算。
 * @param {Object} input 發放
 * @return {Object}
 */
function planPayoutMove(input) {
  const openMinor = Number(input.openMinor || 0);
  const payoutMinor = Number(input.payoutMinor || 0);
  const variance = payoutMinor - openMinor;
  if (variance !== 0 && String(input.reason || "").trim().length < 2) {
    throw new Error("實發金額與可結算不同時，必須填寫調整理由");
  }
  return {
    accrualMonth: input.accrualMonth,
    payoutMonth: input.payoutMonth,
    accrualOpenDelta: -openMinor,
    accrualAdjustmentDelta: variance,
    payoutPaidDelta: payoutMinor,
    variance: variance,
  };
}

/**
 * @param {string} status 目前狀態
 * @param {string} action 目標
 * @return {boolean}
 */
function canChangeCommissionStatus(status, action) {
  const allowed = {
    pending: ["settleable", "cancelled"],
    settleable: ["paid", "cancelled"],
    recovery: ["recovered"],
    paid: [],
    cancelled: [],
    recovered: [],
  };
  return (allowed[status] || []).indexOf(action) >= 0;
}

/**
 * 同月同店的續費只算一家，收款筆數另計。
 * @param {boolean} alreadyCounted 本月已計過這家
 * @return {{shops: number, payments: number}}
 */
function renewalShopDelta(alreadyCounted) {
  return {shops: alreadyCounted ? 0 : 1, payments: 1};
}

/**
 * @param {Object} entry 分潤列
 * @return {Array<Object>}
 */
function summarizeCommissionEntry(entry) {
  const row = entry || {};
  const rep = String(row.beneficiaryRepId || "");
  const month = String(row.accrualMonth || "");
  if (!rep || !month) return [];
  if (row.kind === "recovery") {
    return [{
      repId: rep,
      month: month,
      recoveryMinor: Number(row.amountMinor || 0),
    }];
  }
  const open = row.status === "pending" || row.status === "settleable" ?
    Number(row.openMinor == null ? row.amountMinor || 0 : row.openMinor) : 0;
  const rows = [{
    repId: rep,
    month: month,
    earnedCommissionMinor: Number(row.amountMinor || 0),
    openCommissionMinor: open,
    adjustmentMinor: Number(row.clawedMinor || 0),
  }];
  if (row.status === "paid" && row.paidMonth) {
    rows.push({
      repId: rep,
      month: String(row.paidMonth),
      paidCommissionMinor: Number(
          row.payoutMinor == null ? row.amountMinor || 0 : row.payoutMinor,
      ),
    });
  }
  return rows;
}

/**
 * @param {Array<Object>} items 已排序
 * @param {string} cursor 上一頁最後的 id
 * @param {number} limit 筆數
 * @return {Object}
 */
function sliceStablePage(items, cursor, limit) {
  let start = 0;
  if (cursor) {
    const index = items.findIndex((item) => item.id === cursor);
    start = index < 0 ? items.length : index + 1;
  }
  const page = items.slice(start, start + limit);
  const hasMore = start + limit < items.length;
  return {
    items: page,
    hasMore: hasMore,
    nextCursor: hasMore && page.length ? page[page.length - 1].id : "",
  };
}

/**
 * 確認收款採用的業務快照。shop_commercial 優先，公開店家只補舊資料空欄。
 * 業績計給目前負責業務；沒有交接過則計給原始業務。
 * @param {Object|null} commercial 商業資料
 * @param {Object|null} shop 公開店家
 * @return {Object}
 */
function salesAttribution(commercial, shop) {
  const read = (key) => {
    const primary = commercial && commercial[key];
    if (primary != null && String(primary).trim() !== "") {
      return String(primary).trim();
    }
    const legacy = shop && shop[key];
    if (legacy != null && String(legacy).trim() !== "") {
      return String(legacy).trim();
    }
    return "";
  };
  const originSalesRepId = read("originSalesRepId");
  const currentSalesRepId = read("currentSalesRepId");
  return {
    originSalesRepId: originSalesRepId,
    currentSalesRepId: currentSalesRepId,
    shopSource: read("shopSource"),
    performanceRepId: currentSalesRepId || originSalesRepId,
  };
}

/**
 * @param {boolean} alreadyConfirmed 收款已確認
 * @param {boolean} eventExists 摘要事件已存在
 * @return {boolean}
 */
function shouldApplyPaymentSummary(alreadyConfirmed, eventExists) {
  return !alreadyConfirmed && !eventExists;
}

/**
 * @param {string} plan 方案
 * @param {string} locked 模板
 * @param {Array<string>} existing 既有模組
 * @return {string[]}
 */
function planModules(plan, locked, existing) {
  const lockable = ["cat_hotel", "dog_hotel", "grooming", "hospital", "store"];
  const moduleName = lockable.indexOf(locked) >= 0 ? locked : "cat_hotel";
  const base = plan === "pro" ?
    ["basic_info", ...lockable, "reports"] :
    ["basic_info", moduleName, "reports"];
  (existing || []).forEach((item) => {
    const name = String(item || "");
    if ((name === "daycare" || name === "inventory") &&
      base.indexOf(name) < 0) {
      base.push(name);
    }
  });
  return base;
}

/**
 * @param {Object} shop 店家
 * @param {string} today 今天
 * @return {Object}
 */
function resolvePlanSchedule(shop, today) {
  const currentPlan = String((shop || {}).plan || "");
  const queued = [];
  if (shop && shop.nextPlan && shop.nextPlanStarts) {
    queued.push({
      plan: String(shop.nextPlan),
      starts: String(shop.nextPlanStarts),
    });
  }
  if (shop && shop.followingPlan && shop.followingPlanStarts) {
    queued.push({
      plan: String(shop.followingPlan),
      starts: String(shop.followingPlanStarts),
    });
  }
  queued.sort((left, right) => left.starts < right.starts ? -1 : 1);
  let plan = currentPlan;
  const future = [];
  queued.forEach((item) => {
    if (item.starts <= today) plan = item.plan;
    else future.push(item);
  });
  return {
    effectivePlan: plan,
    applied: plan !== currentPlan,
    nextPlan: future[0] ? future[0].plan : "",
    nextPlanStarts: future[0] ? future[0].starts : "",
    followingPlan: future[1] ? future[1].plan : "",
    followingPlanStarts: future[1] ? future[1].starts : "",
  };
}

/**
 * 到期的下一期方案改寫到實際方案與模組，不改已付服務迄日。
 * @param {Object} shop 店家
 * @param {string} today 今天
 * @return {Object|null}
 */
function materializeDuePlan(shop, today) {
  const resolved = resolvePlanSchedule(shop, today);
  if (!resolved.applied) return null;
  return {
    patch: {
      plan: resolved.effectivePlan,
      enabledModules: planModules(
          resolved.effectivePlan,
          (shop || {}).lockedModule || (shop || {}).businessType,
          (shop || {}).enabledModules,
      ),
      nextPlan: resolved.nextPlan || null,
      nextPlanStarts: resolved.nextPlanStarts || null,
      followingPlan: resolved.followingPlan || null,
      followingPlanStarts: resolved.followingPlanStarts || null,
    },
  };
}

/**
 * @param {Object} shop 店家
 * @param {Object} patch 方案更新
 * @return {Object}
 */
function applyPlanPatch(shop, patch) {
  const next = Object.assign({}, shop || {});
  Object.keys(patch || {}).forEach((key) => {
    if (patch[key] == null || patch[key] === "") delete next[key];
    else next[key] = patch[key];
  });
  return next;
}

/**
 * 權限判斷用的模組。下一期尚未到日，沿用店家文件上的模組。
 * @param {Object} shop 店家
 * @param {string=} today 今天
 * @return {string[]}
 */
function effectiveModules(shop, today) {
  const day = today || taipeiDateKey(new Date());
  const resolved = resolvePlanSchedule(shop || {}, day);
  if (!resolved.applied) {
    return Array.isArray((shop || {}).enabledModules) ?
      (shop || {}).enabledModules.map((item) => String(item)) :
      planModules(
          resolved.effectivePlan,
          (shop || {}).lockedModule,
          [],
      );
  }
  return planModules(
      resolved.effectivePlan,
      (shop || {}).lockedModule || (shop || {}).businessType,
      (shop || {}).enabledModules,
  );
}

/**
 * 同批先依正規化代碼分組。索引已被別人占用或同批重複都列衝突。
 * @param {Array<Object>} rows 本批激活碼
 * @param {Object} keyOwners 正規化代碼對應的 codeId
 * @return {{updates: Array<Object>, conflicts: Array<Object>}}
 */
function planActivationMigration(rows, keyOwners) {
  const groups = new Map();
  (rows || []).forEach((row) => {
    const normalized = normalizeActivationCode(row.code || "");
    if (!normalized) return;
    if (!groups.has(normalized)) groups.set(normalized, []);
    groups.get(normalized).push(row);
  });
  const updates = [];
  const conflicts = [];
  groups.forEach((group, normalized) => {
    const owner = String((keyOwners || {})[normalized] || "");
    const ids = group.map((row) => row.id);
    if (group.length > 1) {
      group.forEach((row) => {
        if (owner && row.id === owner) {
          updates.push(Object.assign({}, row, {
            normalizedCode: normalized,
            bindKey: false,
          }));
          return;
        }
        conflicts.push({
          codeId: row.id,
          normalizedCode: normalized,
          reason: "同批正規化衝突",
          otherCodeIds: ids.filter((id) => id !== row.id),
        });
      });
      return;
    }
    const row = group[0];
    if (owner && owner !== row.id) {
      conflicts.push({
        codeId: row.id,
        normalizedCode: normalized,
        reason: "索引已被其他激活碼使用",
        otherCodeIds: [owner],
      });
      return;
    }
    updates.push(Object.assign({}, row, {
      normalizedCode: normalized,
      bindKey: !owner,
    }));
  });
  return {updates: updates, conflicts: conflicts};
}

/**
 * @param {string} existingCodeId 索引目前指向
 * @param {string} codeId 這筆激活碼
 * @return {Object}
 */
function claimActivationKey(existingCodeId, codeId) {
  if (existingCodeId && existingCodeId !== codeId) {
    return {ok: false, reason: "索引已被其他激活碼使用"};
  }
  return {ok: true, writeKey: true};
}

/**
 * 發布是把重建結果整筆寫上報表，不是再累加一次。
 * @param {Object} rebuild 重建列
 * @param {boolean} alreadyPublished 這列已發布
 * @return {Object}
 */
function planSummaryPublish(rebuild, alreadyPublished) {
  if (alreadyPublished) return {skip: true};
  const row = rebuild || {};
  return {
    skip: false,
    summaryId: `${row.repId}_${row.month}`,
    patch: {
      repId: row.repId,
      month: row.month,
      earnedCommissionMinor: Number(row.earnedCommissionMinor || 0),
      openCommissionMinor: Number(row.openCommissionMinor || 0),
      adjustmentMinor: Number(row.adjustmentMinor || 0),
      paidCommissionMinor: Number(row.paidCommissionMinor || 0),
      recoveryMinor: Number(row.recoveryMinor || 0),
    },
  };
}

module.exports = {
  PLAN_PRICES,
  SOURCES,
  taipeiDateKey,
  normalizeActivationCode,
  addCalendarMonths,
  addDays,
  inclusiveServiceEnd,
  nextPaidPeriod,
  laterDate,
  catalogAmount,
  canUseActivationCode,
  activationStatus,
  activationSourceSnapshot,
  extendEntitlement,
  planPaymentConfirm,
  pickCommissionRule,
  commissionAmount,
  planCommissionRefund,
  planCommissionClawback,
  planRefund,
  planPaymentAmounts,
  planPayoutMove,
  previewPaidPeriod,
  effectiveUseByDate,
  activationCodeLookupValues,
  activationSearchFields,
  activationNameGram,
  canChangeCommissionStatus,
  renewalShopDelta,
  sliceStablePage,
  summarizeCommissionEntry,
  salesAttribution,
  shouldApplyPaymentSummary,
  planModules,
  resolvePlanSchedule,
  materializeDuePlan,
  applyPlanPatch,
  effectiveModules,
  planActivationMigration,
  claimActivationKey,
  planSummaryPublish,
  safeMinor,
  subscriptionListStatus,
  renewalDue,
  legacyEntitlementPatch,
};
