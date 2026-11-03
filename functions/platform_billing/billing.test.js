/* eslint-disable require-jsdoc */
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const Module = require("node:module");
const {createBilling} = require("./service");
const policy = require("./policy");
const {createCheckMacValue, verifyCheckMacValue} = require("../payments/ecpay_mac");
const {gateway} = require("./gateway");
function database(seed) {
  const rows = new Map(Object.entries(seed)); let tail = Promise.resolve();
  function apply(path, data, merge) {
    const old = rows.get(path) || {}; const next = merge ? {...old} : {};
    for (const [key, value] of Object.entries(data)) {
      if (value && value.op === "increment") next[key] = (old[key] || 0) + value.value;
      else if (value && value.op === "delete") delete next[key]; else next[key] = value;
    }
    rows.set(path, structuredClone(next));
  }
  function ref(path) {
    return {path, id: path.split("/").pop(),
      get: async () => snap(path), set: async (data, opts) => apply(path, data, opts && opts.merge),
      update: async (data) => apply(path, data, true),
    };
  }
  function snap(path) {
    return {exists: rows.has(path), id: path.split("/").pop(), ref: ref(path),
      data: () => rows.has(path) ? structuredClone(rows.get(path)) : undefined,
      get: (key) => (rows.get(path) || {})[key]};
  }
  function query(path, filters = [], ordering = "", direction = "asc", max = 1000, cursor = "") {
    return {doc: (id) => ref(path + "/" + id),
      where: (key, op, val) => query(path, [...filters, [key, op, val]], ordering, direction, max, cursor),
      orderBy: (key, dir) => query(path, filters, key, dir, max, cursor),
      limit: (val) => query(path, filters, ordering, direction, val, cursor),
      startAfter: (val) => query(path, filters, ordering, direction, max, val),
      get: async () => ({docs: [...rows.keys()].filter((key) => key.startsWith(path + "/") && key.split("/").length === path.split("/").length + 1)
          .map(snap).filter((doc) => doc.id > cursor && filters.every(([key, op, val]) => (op === "==" ? doc.get(key) === val : op === "<=" && doc.get(key) <= val)))
          .sort((a, b) => {
            const av = ordering === "__name__" || !ordering ? a.id : a.get(ordering); const bv = ordering === "__name__" || !ordering ? b.id : b.get(ordering); return (av < bv ? -1 : av > bv ? 1 : 0) * (direction === "desc" ? -1 : 1);
          }).slice(0, max)}),
    };
  }
  const db = {rows, doc: ref, collection: (path) => query(path), runTransaction: (fn) => {
    const next = tail.then(async () => {
      let writes = false; const changes = [];
      const result = await fn({get: async (r) => {
        assert.equal(writes, false, "transaction reads must precede writes"); return r.get();
      },
      create: (r, data) => {
        writes = true; changes.push(() => {
          assert.equal(rows.has(r.path), false); apply(r.path, data, false);
        });
      },
      set: (r, data, opts) => {
        writes = true; changes.push(() => apply(r.path, data, opts && opts.merge));
      },
      update: (r, data) => {
        writes = true; changes.push(() => apply(r.path, data, true));
      },
      });
      changes.forEach((change) => change()); return result;
    }); tail = next.catch(() => {}); return next;
  }};
  return db;
}
function fixture(environment = "production", overrides = {}) {
  let time = Date.parse("2026-11-02T14:00:00Z");
  const db = database({"shops/s1": {ownerUid: "owner", plan: "basic", ...overrides}, "shops/s2": {ownerUid: "other"}});
  const keys = {hashKey: "test-key", hashIv: "test-iv"};
  const sign = (data) => ({...data, CheckMacValue: createCheckMacValue({data, ...keys})});
  let queryResult = null; let cancelError = false; let settleError = false; let settled = 0;
  const provider = {config: {merchantId: "3002607", environment, checkoutUrl: "https://example.invalid/checkout"},
    verify: (data) => verifyCheckMacValue({data, ...keys}), form: () => "<form></form>",
    query: async (order) => queryResult || (order.recurring ? {
      MerchantID: "3002607", MerchantTradeNo: order.id, RtnCode: 1, PeriodType: "M", Frequency: 1, ExecTimes: 12, PeriodAmount: 999,
      TotalSuccessTimes: 1, TotalSuccessAmount: 999, ExecStatus: "1",
      ExecLog: [{RtnCode: 1, amount: 999, gwsr: 11, process_date: "2026/11/02 22:00:00", TradeNo: "ECPAYTRADE001"}],
    } : {MerchantID: "3002607", MerchantTradeNo: order.id, TradeStatus: "1", TradeAmt: "999", PaymentType: "Credit_CreditCard", TradeNo: "ECPAYTRADE001", PaymentDate: "2026/11/02 22:00:00"}),
    cancel: async () => {
      if (cancelError) throw Error("timeout");
    },
  };
  const original = Module._load;
  const filename = require.resolve("../sales/commercial_ops"); delete require.cache[filename];
  const firestore = Object.assign(() => db, {FieldValue: {serverTimestamp: () => time, increment: (value) => ({op: "increment", value}), delete: () => ({op: "delete"})}, Timestamp: {fromDate: (date) => date.getTime()}});
  let ops;
  try {
    Module._load = function(name, ...args) {
      return name === "firebase-admin" ? {firestore} : original.call(this, name, ...args);
    }; ops = require(filename);
  } finally {
    Module._load = original;
  }
  const core = createBilling({db, environment, enabled: true, provider, now: () => time, stamp: () => time,
    settle: async (id, date, servicePeriod) => {
      if (settleError) throw Error("settlement interrupted"); settled++; return ops.confirmSubscriptionPayment({uid: "system_ecpay_platform", enabled: true, permissions: ["manage_subscription_finance"]}, {paymentId: id}, {paymentDate: date, servicePeriod, verifiedGateway: true});
    }});
  const input = (extra = {}) => ({shopId: "s1", plan: "basic", cycle: "month", recurring: false, consent: true, termsVersion: policy.TERMS, priceVersion: policy.PRICE_VERSION, requestId: "request_000000000001", ...extra});
  const order = (id) => db.rows.get("platform_billing_orders/" + id);
  const first = (id, extra = {}) => sign({MerchantID: "3002607", MerchantTradeNo: id, RtnCode: "1", TradeAmt: "999", PaymentType: "Credit_CreditCard", TradeNo: "ECPAYTRADE001", PaymentDate: "2026/11/02 22:00:00", ...extra});
  return {db, core, input, sign, first, order, ops, provider, keys, time: () => time, setTime: (v) => {
    time = Date.parse(v);
  }, setQuery: (v) => {
    queryResult = v;
  }, cancelFailure: (v) => {
    cancelError = v;
  }, settleFailure: (v) => {
    settleError = v;
  }, settled: () => settled};
}
test("only the actual shop owner may create a payment, never an employee or other shop", async () => {
  const f = fixture(); await assert.rejects(f.core.checkout("staff", f.input()), {code: "permission-denied"});
  await assert.rejects(f.core.status("owner", "s2"), {code: "permission-denied"});
  assert.equal([...f.db.rows.keys()].filter((key) => key.startsWith("platform_billing_orders/")).length, 0);
});
test("server price and explicit versioned consent reject card fields, amounts, stale prices and missing consent", async () => {
  const f = fixture();
  for (const data of [f.input({cardNumber: "not-a-card"}), f.input({amountMinor: 1}), f.input({consent: false}), f.input({priceVersion: "f".repeat(64)}), f.input({termsVersion: "forged"})]) await assert.rejects(f.core.checkout("owner", data));
  const result = await f.core.checkout("owner", f.input()); assert.equal(result.order.amountMinor, 99900);
  assert.equal(result.checkoutUrl.includes("#"), true); assert.equal(result.checkoutUrl.includes("?"), false);
  const stored = f.order(result.order.id); assert.equal(stored.launchHash.length, 64); assert.equal(JSON.stringify(stored).includes(result.checkoutUrl.split(".").pop()), false);
});
test("same request and new tabs resume one pending order; old resume cannot charge a second period", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  const b = await f.core.checkout("owner", f.input({requestId: "another_request_001"}));
  assert.equal(a.order.id, b.order.id);
  await f.core.callback(f.first(a.order.id), false);
  await assert.rejects(f.core.checkout("owner", f.input({requestId: "another_request_001"})), {code: "failed-precondition"});
  assert.equal([...f.db.rows.keys()].filter((key) => key.startsWith("platform_billing_orders/")).length, 1);
});
test("launch token expiry and replacement cannot unlock a different or paid order", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  const token = a.checkoutUrl.split("#")[1].split(".")[1];
  assert.equal((await f.core.launch(a.order.id, token)).html, "<form></form>");
  await f.core.checkout("owner", f.input()); await assert.rejects(f.core.launch(a.order.id, token));
  const c = await f.core.checkout("owner", f.input());
  f.setTime("2026-11-02T14:11:00Z"); await assert.rejects(f.core.launch(a.order.id, c.checkoutUrl.split("#")[1].split(".")[1]));
});
test("trial and prepaid time are preserved; recurring cannot silently charge before the entitlement ends", async () => {
  const f = fixture("production", {trialUntil: "2026-12-31", paidUntilDate: "2026-12-31"});
  await assert.rejects(f.core.checkout("owner", f.input({recurring: true})), {code: "failed-precondition"});
  const a = await f.core.checkout("owner", f.input()); await f.core.callback(f.first(a.order.id), false);
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, "2027-01-31");
});
test("verified first payment atomically reaches original ledger, entitlement and sales summary once", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input()); const data = f.first(a.order.id);
  await Promise.all([f.core.callback(data, false), f.core.callback(data, false)]);
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, "2026-12-01");
  assert.equal(f.db.rows.get(`shop_subscription_payments/${a.order.id}_1`).status, "confirmed");
  assert.equal(f.db.rows.get("sales_month_summaries/platform_2026-11").collectedMinor, 99900);
  assert.equal(f.order(a.order.id).settledCount, 1);
});
test("forged MAC, different merchant, incorrect amount and simulated notices never grant service", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  for (const data of [{...f.first(a.order.id), TradeAmt: "1"}, f.first(a.order.id, {MerchantID: "9999999"}), f.first(a.order.id, {TradeAmt: "1"}), f.first(a.order.id, {SimulatePaid: "1"})]) await assert.rejects(f.core.callback(data, false));
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, undefined);
});
test("card fragments and raw messages are discarded even on valid signed callbacks", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  await f.core.callback(f.first(a.order.id, {card4no: "1234", card6no: "666666", cardValidMM: "12", RtnMsg: "PRIVATECARDMARKER"}), false);
  const saved = JSON.stringify([...f.db.rows.values()]); assert.equal(saved.includes("PRIVATECARDMARKER"), false);
  assert.equal(saved.includes("\"card4no\""), false); assert.equal(saved.includes("\"card6no\""), false);
});
test("test gateway authorizations never touch real entitlement, revenue, or real payment ledger", async () => {
  const f = fixture("test"); const before = structuredClone(f.db.rows.get("shops/s1"));
  const a = await f.core.checkout("owner", f.input()); await f.core.callback(f.first(a.order.id), false);
  assert.deepEqual(f.db.rows.get("shops/s1"), before); assert.equal(f.settled(), 0);
  assert.equal([...f.db.rows.keys()].some((key) => key.startsWith("shop_subscription_payments/") || key.startsWith("sales_month_summaries/")), false);
  assert.equal(f.db.rows.get(`platform_billing_test_receipts/${a.order.id}_1`).status, "test_confirmed");
});
test("failure neither extends service nor overwrites a confirmed payment", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  await f.core.callback(f.first(a.order.id, {RtnCode: "10100058"}), false);
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, undefined);
  await f.core.callback(f.first(a.order.id), false);
  await f.core.callback(f.first(a.order.id, {RtnCode: "10100058"}), false);
  assert.equal(f.order(a.order.id).state, "completed");
});
test("settlement crash is recoverable without double collection or entitlement", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  f.settleFailure(true); await assert.rejects(f.core.callback(f.first(a.order.id), false));
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, undefined);
  f.settleFailure(false); await f.core.drain(a.order.id); await f.core.drain(a.order.id);
  assert.equal(f.db.rows.get("sales_month_summaries/platform_2026-11").collectedMinor, 99900);
});
test("cancellation timeout remains pending and blocks new subscriptions", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input({recurring: true}));
  await f.core.callback(f.first(a.order.id), false); const until = f.db.rows.get("shops/s1").paidServiceUntil;
  f.cancelFailure(true); await assert.rejects(f.core.cancel("owner", "s1"));
  assert.equal(f.order(a.order.id).state, "cancel_pending");
  await assert.rejects(f.core.checkout("owner", f.input({requestId: "new_request_0000002"})));
  f.cancelFailure(false); await f.core.cancel("owner", "s1");
  assert.equal(f.order(a.order.id).state, "cancelled"); assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, until);
});
test("query recovers missed periodic notices in order and discards the returned card fragments", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input({recurring: true}));
  f.setTime("2026-12-02T14:00:00Z");
  f.setQuery({MerchantID: "3002607", MerchantTradeNo: a.order.id, RtnCode: 1,
    PeriodType: "M", Frequency: 1, ExecTimes: 12, PeriodAmount: 999, TotalSuccessTimes: 2, TotalSuccessAmount: 1998, ExecStatus: "1", card4no: "1234",
    ExecLog: [{RtnCode: 1, amount: 999, gwsr: 11, process_date: "2026/11/02 22:00:00", TradeNo: "ECPAYTRADE001"},
      {RtnCode: 1, amount: 999, gwsr: 22, process_date: "2026/12/02 22:00:00", TradeNo: "ECPAYTRADE002"}]});
  await f.core.refresh("owner", "s1"); await f.core.refresh("owner", "s1");
  assert.equal(f.order(a.order.id).settledCount, 2);
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, "2027-01-01");
  assert.equal(JSON.stringify([...f.db.rows.values()]).includes("\"card4no\""), false);
});
test("manual confirmation cannot forge an ECPay receipt or bypass callback verification", async () => {
  const f = fixture(); f.db.rows.set("shop_subscription_payments/fake", {provider: "ecpay_platform", providerVerified: true, shopId: "s1", status: "draft"});
  await assert.rejects(f.ops.confirmSubscriptionPayment({uid: "admin", enabled: true, permissions: ["manage_subscription_finance"]}, {paymentId: "fake"}), {code: "permission-denied"});
});
test("gateway renders only hosted credit checkout, no card-memory parameters or sensitive logs", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input({recurring: true}));
  const client = gateway({...f.provider.config, ...f.keys, publicOrigin: "https://example.invalid", callbackUrl: "https://example.invalid/first", periodicUrl: "https://example.invalid/periodic"}, () => {
    throw Error("must not request gateway");
  });
  const html = client.form(f.order(a.order.id), "nonce123");
  assert.match(html, /payment.ecpay.com.tw/); assert.match(html, /name="NeedExtraPaidInfo" value="N"/);
  assert.match(html, /name="PeriodAmount" value="999"/); assert.match(html, /name="BindingCard" value="0"/);
  assert.doesNotMatch(html, /MerchantMemberID|card4no|card6no|CardNumber|HashKey|HashIV/);
});

test("valid notification without gateway query confirmation cannot grant a plan", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  f.setQuery({MerchantID: "3002607", MerchantTradeNo: a.order.id, TradeStatus: "0"});
  await assert.rejects(f.core.callback(f.first(a.order.id), false), {code: "unavailable"});
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, undefined);
  assert.equal(f.order(a.order.id).requiresReconcile, true);
});
test("single-payment missed callback recovers through the official TradeStatus query", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  await f.core.refresh("owner", "s1");
  assert.equal(f.order(a.order.id).state, "completed");
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, "2026-12-01");
});
test("unsent checkout can be cancelled locally; old short-lived link can never pay it", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input());
  const token = a.checkoutUrl.split("#")[1].split(".")[1];
  await f.core.cancel("owner", "s1");
  await assert.rejects(f.core.launch(a.order.id, token));
  assert.equal(f.order(a.order.id).state, "cancelled");
  await assert.rejects(f.core.checkout("owner", f.input()));
});
test("deletion cannot race an unfinished recurring contract or an issued payment", async () => {
  const {assertNoPlatformBilling} = require("./service");
  const f = fixture(); const a = await f.core.checkout("owner", f.input({recurring: true}));
  await assert.rejects(f.db.runTransaction((tx) => assertNoPlatformBilling(tx, f.db, "s1")), {code: "failed-precondition"});
  await f.core.cancel("owner", "s1");
  await f.db.runTransaction((tx) => assertNoPlatformBilling(tx, f.db, "s1"));
  assert.equal(f.order(a.order.id).state, "cancelled");
});
test("suspended and deleting shops cannot be charged by a new checkout", async () => {
  for (const flags of [{status: "suspended"}, {deletionState: "deleting"}]) {
    const f = fixture("production", flags); await assert.rejects(f.core.checkout("owner", f.input()), {code: "failed-precondition"});
  }
});
test("legacy entitlement date also blocks premature automatic billing", async () => {
  const f = fixture("production", {paidUntilDate: "2026-12-31"});
  await assert.rejects(f.core.checkout("owner", f.input({recurring: true})), {code: "failed-precondition"});
});
test("cancelled subscription keeps already paid period, and platform finance can terminate", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input({recurring: true}));
  await f.core.callback(f.first(a.order.id), false);
  f.db.rows.set("platform_users/finance", {enabled: true, permissions: ["manage_subscription_finance"]});
  await f.core.cancel("finance", "s1");
  assert.equal(f.order(a.order.id).state, "cancelled");
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, "2026-12-01");
  assert.equal((await f.core.status("finance", "s1")).canCheckout, false);
});
test("recurring callback cannot skip missing authorizations or alter cycle and amount", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input({recurring: true}));
  const periodic = f.sign({MerchantID: "3002607", MerchantTradeNo: a.order.id, RtnCode: 1, Amount: 999,
    PeriodType: "M", Frequency: 1, ExecTimes: 12, TotalSuccessTimes: 2, gwsr: 22, ProcessDate: "2026/11/02 22:00:00"});
  await assert.rejects(f.core.callback(periodic, true));
  await assert.rejects(f.core.callback(f.sign({...periodic, Frequency: 2}), true));
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, undefined);
});
test("gateway query and cancel verify signatures, exact merchant and no redirect", async () => {
  const config = {environment: "test", merchantId: "3002607", hashKey: "k", hashIv: "i"};
  let captured;
  const payload = {MerchantID: config.merchantId, MerchantTradeNo: "PB123456789012345678", RtnCode: "1"};
  payload.CheckMacValue = createCheckMacValue({data: payload, hashKey: "k", hashIv: "i"});
  const client = gateway(config, async (url, request) => {
    captured = {url, request}; return {ok: true, text: async () => new URLSearchParams(payload).toString()};
  });
  await client.cancel({id: payload.MerchantTradeNo});
  assert.equal(captured.url, "https://payment-stage.ecpay.com.tw/Cashier/CreditCardPeriodAction");
  assert.equal(captured.request.redirect, "error");
  payload.CheckMacValue = "0".repeat(64);
  await assert.rejects(client.cancel({id: payload.MerchantTradeNo}));
});

test("manual subscription registration and historical drafts cannot create paid entitlement", async () => {
  const f = fixture();
  const admin = {uid: "admin", enabled: true, permissions: ["manage_subscription_finance"]};
  for (const method of ["cash", "transfer", "ecpay_platform"]) {
    await assert.rejects(f.ops.registerSubscriptionPayment(admin, {shopId: "s1", method}), {code: "failed-precondition"});
  }
  f.db.rows.set("shop_subscription_payments/manual", {shopId: "s1", plan: "basic", cycle: "month", amountReceivedMinor: 99900, status: "draft"});
  await assert.rejects(f.ops.confirmSubscriptionPayment(admin, {paymentId: "manual"}), {code: "failed-precondition"});
  assert.equal(f.db.rows.get("shop_subscription_payments/manual").status, "draft");
  assert.equal(f.db.rows.get("shops/s1").paidUntilDate, undefined);
});
test("only the two monthly ECPay prices are offered and yearly checkout is rejected", async () => {
  const f = fixture(); const view = await f.core.status("owner", "s1");
  assert.deepEqual(view.quotes.map((q) => [q.plan, q.cycle, q.amountMinor]), [["basic", "month", 99900], ["pro", "month", 199900]]);
  await assert.rejects(f.core.checkout("owner", f.input({cycle: "year"})), {code: "failed-precondition"});
  assert.throws(() => policy.quote({}, "basic", "year", false), {code: "failed-precondition"});
});

test("manual refund record cannot claim an ECPay refund without actually refunding at the gateway", async () => {
  const f = fixture(); f.db.rows.set("shop_subscription_payments/paid", {provider: "ecpay_platform", shopId: "s1", status: "confirmed", amountReceivedMinor: 99900});
  await assert.rejects(f.ops.refundSubscriptionPayment({uid: "admin", enabled: true, permissions: ["manage_subscription_finance"]}, {paymentId: "paid", requestId: "refund_request_01", refundMinor: 99900, reason: "testing"}), {code: "failed-precondition"});
  assert.equal(f.db.rows.get("shop_subscription_payments/paid").status, "confirmed");
});

test("monthly billing keeps the original anchor through short months and skipped failed cycles", () => {
  assert.deepEqual(policy.recurringPeriod("2027-01-31", "2027-02-28", "month"), {start: "2027-02-28", end: "2027-03-30"});
  assert.deepEqual(policy.recurringPeriod("2027-01-31", "2027-03-31", "month"), {start: "2027-03-31", end: "2027-04-29"});
  assert.deepEqual(policy.recurringPeriod("2026-11-02", "2027-01-02", "month"), {start: "2027-01-02", end: "2027-02-01"});
  assert.deepEqual(policy.recurringPeriod("2028-02-29", "2029-02-28", "year"), {start: "2029-02-28", end: "2030-02-27"});
});
test("manual renewal cannot overlap an active automatic contract", async () => {
  const f = fixture(); await f.core.checkout("owner", f.input({recurring: true}));
  f.db.rows.set("shop_subscription_payments/manual", {shopId: "s1", plan: "basic", cycle: "month", amountReceivedMinor: 99900, status: "draft"});
  await assert.rejects(f.ops.confirmSubscriptionPayment({uid: "admin", enabled: true, permissions: ["manage_subscription_finance"]}, {paymentId: "manual"}), {code: "failed-precondition"});
});

test("scheduled reconciliation queries only due orders, and not every active shop", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input({recurring: true}));
  await f.core.launch(a.order.id, a.checkoutUrl.split("#")[1].split(".")[1]);
  let queries = 0; const original = f.provider.query;
  f.provider.query = async (order) => {
    queries++; return original(order);
  };
  await f.core.reconcile(); assert.equal(queries, 0);
  f.setTime("2026-11-02T14:11:00Z"); await f.core.reconcile();
  assert.equal(queries, 1); assert.equal(f.order(a.order.id).state, "active");
  await f.core.reconcile(); assert.equal(queries, 1);
});
test("scheduled requested cancellation still runs when gateway query is unavailable", async () => {
  const f = fixture(); const a = await f.core.checkout("owner", f.input({recurring: true}));
  await f.core.callback(f.first(a.order.id), false);
  f.cancelFailure(true); await assert.rejects(f.core.cancel("owner", "s1"));
  f.cancelFailure(false); f.provider.query = async () => {
    throw Error("query outage");
  };
  f.setTime("2026-11-02T14:02:00Z");
  const result = await f.core.reconcile(); assert.deepEqual(result.failures, []);
  assert.equal(f.order(a.order.id).state, "cancelled");
  assert.equal(f.db.rows.get("shops/s1").paidServiceUntil, "2026-12-01");
});
