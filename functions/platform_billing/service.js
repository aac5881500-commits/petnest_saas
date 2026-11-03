/* eslint-disable max-len, require-jsdoc */
"use strict";
const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const rules = require("./policy");
const commercial = require("../sales/commercial_policy");
const {ROOT_ADMIN_UID, hasPlatformAccess} = require("../legal_pet/access");
const LOCKED = ["pending", "active", "past_due", "paused", "cancel_pending"];
function createBilling({db, environment, enabled, provider, settle,
  now = () => Date.now(), stamp = () => new Date()}) {
  const orders = db.collection("platform_billing_orders");
  const account = (shopId) => db.collection("platform_billing_accounts").doc(`${environment}_${shopId}`);
  const ledger = (order) => db.collection(order.environment === "production" ? "shop_subscription_payments" : "platform_billing_test_receipts");
  function nextCheck(row) {
    if (row.state === "active" && row.lastServiceEnd) {
      const due = commercial.addDays(row.lastServiceEnd, 1);
      return Math.max(now() + 60000, Date.parse(due + "T00:30:00+08:00"));
    }
    return now() + 1800000;
  }
  async function finance(uid) {
    if (uid === ROOT_ADMIN_UID) return true;
    const user = await db.collection("platform_users").doc(uid).get();
    return user.exists && hasPlatformAccess({...user.data(), uid}, ["manage_subscription_finance"]);
  }
  async function owner(uid, shopId, readOnly = false) {
    if (!uid) throw new HttpsError("unauthenticated", "請先登入店主帳號");
    if (typeof shopId !== "string" || !/^[A-Za-z0-9_-]{1,100}$/.test(shopId)) throw new HttpsError("invalid-argument", "店家編號不正確");
    const shop = await db.collection("shops").doc(shopId).get();
    if (!shop.exists) throw new HttpsError("not-found", "找不到店家");
    if (shop.get("ownerUid") !== uid && !(readOnly && await finance(uid))) throw new HttpsError("permission-denied", "只有店主可管理平台收費");
    return shop.data();
  }
  async function status(uid, shopId) {
    const shop = await owner(uid, shopId, true);
    const acc = await account(shopId).get();
    const order = acc.exists && acc.get("orderId") ? await orders.doc(acc.get("orderId")).get() : null;
    const history = await db.collection(environment === "production" ? "shop_subscription_payments" : "platform_billing_test_receipts")
        .where("shopId", "==", shopId).orderBy("createdAt", "desc").limit(12).get();
    const quotes = [];
    for (const plan of ["basic", "pro"]) for (const cycle of ["month"]) quotes.push(rules.quote(shop, plan, cycle, false, now()));
    return {enabled, environment, canCheckout: shop.ownerUid === uid && shop.status !== "suspended" && shop.accountStatus !== "suspended" && shop.deletionState !== "deleting", canCancel: shop.ownerUid === uid || await finance(uid), priceVersion: rules.PRICE_VERSION, termsVersion: rules.TERMS, plan: shop.plan || "free", quotes,
      paidUntilDate: shop.paidUntilDate || "", paidServiceUntil: shop.paidServiceUntil || "",
      subscription: rules.publicOrder(order && order.exists ? order.data() : null),
      receipts: history.docs.map((doc) => {
        const row = doc.data();
        return {id: doc.id, status: row.status, plan: row.plan, cycle: row.cycle,
          amountMinor: row.amountReceivedMinor, paymentDate: row.paymentDate,
          serviceStart: row.serviceStart || "", serviceEnd: row.serviceEnd || "", test: environment !== "production"};
      })};
  }
  async function checkout(uid, input) {
    const data = rules.checkoutInput(input);
    await owner(uid, data.shopId);
    if (!enabled || !provider) throw new HttpsError("failed-precondition", "平台綠界線上付款尚未開通，目前不會收費");
    const id = rules.orderId(`${environment}:${uid}`, data.requestId);
    const result = await db.runTransaction(async (tx) => {
      const shopRef = db.collection("shops").doc(data.shopId);
      const requestRef = db.collection("platform_billing_requests").doc(id);
      const [shopSnap, accSnap, alias] = await Promise.all([tx.get(shopRef), tx.get(account(data.shopId)), tx.get(requestRef)]);
      const replay = await tx.get(orders.doc(alias.exists ? alias.get("orderId") : id));
      if (shopSnap.exists && (shopSnap.get("deletionState") === "deleting" || shopSnap.get("accountStatus") === "suspended" || ["suspended", "deleted"].includes(shopSnap.get("status")))) throw new HttpsError("failed-precondition", "店家目前停權或刪除中，請先聯絡平台確認，暫不收費");
      if (!shopSnap.exists || shopSnap.get("ownerUid") !== uid) throw new HttpsError("permission-denied", "店主身分已變更");
      const current = accSnap.exists && accSnap.get("orderId") ? await tx.get(orders.doc(accSnap.get("orderId"))) : null;
      if (replay.exists) {
        const old = replay.data();
        if (old.payerUid !== uid || old.shopId !== data.shopId || old.plan !== data.plan || old.cycle !== data.cycle || old.recurring !== data.recurring || old.priceVersion !== data.priceVersion) throw new HttpsError("already-exists", "此付款請求已用於其他方案");
        if (old.state !== "pending") throw new HttpsError("failed-precondition", "此筆付款已處理，請重新查詢狀態");
        return old;
      }
      if (current && current.exists && LOCKED.includes(current.get("state"))) {
        const old = current.data();
        if (old.state === "pending" && old.payerUid === uid && old.plan === data.plan && old.cycle === data.cycle && old.recurring === data.recurring && old.priceVersion === data.priceVersion) {
          tx.create(requestRef, {orderId: old.id, payerUid: uid, shopId: data.shopId});
          return old;
        }
        throw new HttpsError("failed-precondition", "已有待付款或自動續訂，請先處理原付款／取消續訂，避免重複收費");
      }
      if (data.priceVersion !== rules.PRICE_VERSION) throw new HttpsError("failed-precondition", "平台價格已更新，請重新載入並確認金額");
      const quoted = rules.quote(shopSnap.data(), data.plan, data.cycle, data.recurring, now());
      if (data.recurring && !quoted.canStartRecurring) throw new HttpsError("failed-precondition", `目前服務仍有效，自動續訂請於${quoted.recurringAvailableFrom}開始；綠界首筆會立即扣款`);
      const order = {...quoted, id, shopId: data.shopId, payerUid: uid,
        environment, merchantId: provider.config.merchantId, createdAtMs: now(),
        consentAtMs: now(), termsVersion: rules.TERMS, state: "pending", settledCount: 0,
        requiresReconcile: true, nextCheckAtMs: now() + 600000};
      tx.create(orders.doc(id), order);
      tx.create(requestRef, {orderId: id, payerUid: uid, shopId: data.shopId});
      tx.set(account(data.shopId), {orderId: id, updatedAtMs: now()});
      return order;
    });
    const token = crypto.randomBytes(24).toString("hex");
    await orders.doc(result.id).update({launchHash: crypto.createHash("sha256").update(token).digest("hex"), launchExpiresAtMs: now() + 600000});
    // Fragment is never transmitted in HTTP access logs or Referer headers.
    return {order: rules.publicOrder(result), checkoutUrl: `${provider.config.checkoutUrl}#${result.id}.${token}`};
  }
  async function launch(id, token) {
    if (!enabled) throw new HttpsError("failed-precondition", "平台已暫停新的線上付款，請聯絡平台");
    if (!/^PB[A-F0-9]{18}$/.test(String(id)) || !/^[a-f0-9]{48}$/.test(String(token))) throw new HttpsError("permission-denied", "請從店主方案頁開啟付款");
    const order = await db.runTransaction(async (tx) => {
      const snap = await tx.get(orders.doc(id));
      const row = snap.data();
      const hash = crypto.createHash("sha256").update(token).digest("hex");
      if (!row || row.environment !== environment || row.state !== "pending" || row.launchExpiresAtMs <= now() ||
          typeof row.launchHash !== "string" || row.launchHash.length !== hash.length ||
          !crypto.timingSafeEqual(Buffer.from(hash), Buffer.from(row.launchHash))) throw new HttpsError("permission-denied", "付款連結已失效，請回店主方案頁重新開啟");
      tx.update(orders.doc(id), {launchIssuedAtMs: row.launchIssuedAtMs || now(), nextCheckAtMs: now() + 600000});
      return row;
    });
    const nonce = crypto.randomBytes(16).toString("hex");
    return {nonce, html: provider.form(order, nonce)};
  }
  async function remember(order, receipt) {
    const paymentId = `${order.id}_${receipt.sequence}`;
    await db.runTransaction(async (tx) => {
      const ref = ledger(order).doc(paymentId);
      const existing = await tx.get(ref);
      if (existing.exists) {
        if (existing.get("gatewayReference") !== receipt.gatewayReference) throw new HttpsError("failed-precondition", "同一期出現不同交易，需由平台對帳");
        return;
      }
      tx.create(ref, {shopId: order.shopId, plan: order.plan, cycle: order.cycle,
        priceMinor: order.amountMinor, standardPriceMinor: order.amountMinor,
        amountDueMinor: receipt.amountMinor, amountReceivedMinor: receipt.amountMinor,
        paymentDate: receipt.paymentDate, provider: "ecpay_platform", providerVerified: true,
        providerOrderId: order.id, gatewaySequence: receipt.sequence,
        gatewayReference: receipt.gatewayReference, paidAtMs: receipt.paidAtMs,
        method: "ecpay_platform_credit", status: "draft", currency: "TWD",
        refundedMinor: 0, refundProgress: "none", createdBy: order.payerUid, createdAt: stamp()});
    });
  }
  async function drain(id) {
    for (let step = 0; step < 12; step++) {
      const snap = await orders.doc(id).get();
      if (!snap.exists) return;
      const order = snap.data();
      const sequence = order.settledCount + 1;
      if (sequence > order.executionLimit) return;
      const ref = ledger(order).doc(`${id}_${sequence}`);
      const payment = await ref.get();
      if (!payment.exists) return;
      if (order.environment === "production") {
        // The existing atomic settlement extends plans and records commissions.
        // No client controls this service actor or the trusted receipt date.
        const first = await ledger(order).doc(`${id}_1`).get();
        const period = order.recurring ? rules.recurringPeriod(first.get("paymentDate"), payment.get("paymentDate"), order.cycle) : null;
        await settle(ref.id, payment.get("paymentDate"), period);
      } else if (payment.get("status") !== "test_confirmed") {
        const shop = await db.collection("shops").doc(order.shopId).get();
        const period = commercial.previewPaidPeriod(shop.data() || {}, payment.get("paymentDate"), order.cycle === "year" ? 12 : 1);
        await ref.update({status: "test_confirmed", serviceStart: period.start, serviceEnd: period.end});
      }
      const confirmed = await ref.get();
      if (!["confirmed", "test_confirmed"].includes(confirmed.get("status"))) throw new HttpsError("unavailable", "收款已收到，方案仍在同步中");
      await db.runTransaction(async (tx) => {
        const latest = await tx.get(orders.doc(id));
        if (latest.get("settledCount") >= sequence) return;
        const row = latest.data();
        const terminal = ["cancelled", "cancel_pending", "paused"].includes(row.state);
        const state = terminal ? row.state : (sequence >= row.executionLimit ? "completed" : "active");
        tx.update(orders.doc(id), {settledCount: sequence, state, lastServiceEnd: confirmed.get("serviceEnd"),
          lastErrorCode: "", nextCheckAtMs: nextCheck({state, lastServiceEnd: confirmed.get("serviceEnd")}), requiresReconcile: LOCKED.includes(state), updatedAtMs: now()});
        tx.set(db.collection("shop_notifications").doc(`billing_${id}_${sequence}`), {
          shopId: row.shopId, type: "plan", status: "unread", title: order.environment === "production" ? "平台方案付款成功" : "平台方案測試付款成功",
          content: order.environment === "production" ? `平台方案已收款，服務至${confirmed.get("serviceEnd")}。${row.recurring && sequence >= row.executionLimit ? "已達約定期數，期滿不再自動扣款，續用時請重新授權。" : ""}` : "此為綠界測試，未收取實款，也未延長正式服務。", createdAt: stamp()});
      });
    }
  }
  async function failure(order, code, first) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(orders.doc(order.id));
      const firstReceipt = first ? await tx.get(ledger(order).doc(`${order.id}_1`)) : null;
      if (firstReceipt && firstReceipt.exists) return;
      if (!snap.exists || ["completed", "cancelled", "cancel_pending"].includes(snap.get("state"))) return;
      // A delayed failed authorization must never overwrite a confirmed receipt.
      if (first && snap.get("settledCount") > 0) return;
      tx.update(orders.doc(order.id), {state: first ? "failed" : "past_due", lastErrorCode: code,
        requiresReconcile: !first, nextCheckAtMs: now() + 1800000, updatedAtMs: now()});
      tx.set(db.collection("shop_notifications").doc(`billing_failed_${order.id}`), {
        shopId: order.shopId, type: "plan", status: "unread", title: "平台方案扣款未完成",
        content: "尚未延長服務期限，請到方案與續費查看，或聯絡平台。", createdAt: stamp()});
    });
  }
  async function callback(data, periodic) {
    const id = typeof data.MerchantTradeNo === "string" ? data.MerchantTradeNo : "";
    if (!/^PB[A-F0-9]{18}$/.test(id)) throw new HttpsError("invalid-argument", "交易編號不正確");
    const snap = await orders.doc(id).get();
    if (!snap.exists) throw new HttpsError("not-found", "找不到平台收費交易");
    const order = snap.data();
    if (order.environment !== environment || !provider.verify(data)) throw new HttpsError("permission-denied", "綠界通知驗證失敗");
    const paid = rules.receipt(order, data, periodic, now());
    if (!paid.success) {
      await failure(order, paid.code, !periodic); return;
    }
    const known = await ledger(order).doc(`${id}_${paid.sequence}`).get();
    if (known.exists && known.get("gatewayReference") === paid.gatewayReference) {
      await drain(id);
      return;
    }
    const shouldQuery = await db.runTransaction(async (tx) => {
      const [latest, existing] = await Promise.all([tx.get(orders.doc(id)), tx.get(ledger(order).doc(`${id}_${paid.sequence}`))]);
      if (existing.exists) return false;
      const key = `${paid.sequence}:${paid.gatewayReference}`;
      if (latest.get("lastVerifyKey") === key && now() - (latest.get("lastQueryAtMs") || 0) < 600000) return false;
      tx.update(orders.doc(id), {requiresReconcile: true, lastCallbackAtMs: now(), lastVerifyKey: key, lastQueryAtMs: now(), nextCheckAtMs: now() + 600000});
      return true;
    });
    if (!shouldQuery) {
      await drain(id); return;
    }
    // Follow the gateway's notification guidance: verify with its server query,
    // not the browser return page or a callback alone. Pending bank replies
    // remain pending and are recovered by refresh / scheduled reconciliation.
    const queried = await provider.query(order);
    const confirmed = rules.queryReceipts(order, queried, now());
    if (!confirmed.some((row) => row.sequence === paid.sequence && row.gatewayReference === paid.gatewayReference)) throw new HttpsError("unavailable", "綠界仍在確認，尚未延長方案");
    for (const row of confirmed) await remember(order, row);
    await drain(id);
  }
  async function sync(id) {
    const snap = await orders.doc(id).get();
    if (!snap.exists || snap.get("environment") !== environment) return;
    const order = snap.data();
    await orders.doc(id).update({lastQueryAtMs: now(), nextCheckAtMs: now() + 1800000});
    const data = await provider.query(order);
    const receipts = rules.queryReceipts(order, data, now());
    for (const receipt of receipts) await remember(order, receipt);
    await drain(id);
    if (order.recurring && ["0", "2", "3"].includes(String(data.ExecStatus))) {
      const state = {"0": "cancelled", "2": "completed", "3": "paused"}[String(data.ExecStatus)];
      await orders.doc(id).update({state, requiresReconcile: state === "paused", updatedAtMs: now()});
    }
    const latest = await orders.doc(id).get();
    if (latest.get("requiresReconcile")) await orders.doc(id).update({nextCheckAtMs: nextCheck(latest.data())});
    return data;
  }
  async function refresh(uid, shopId) {
    await owner(uid, shopId, true);
    const acc = await account(shopId).get();
    if (acc.exists && acc.get("orderId") && provider) {
      const ref = orders.doc(acc.get("orderId"));
      // Bound gateway polling per shop, across tabs and manual refreshes.
      const allowed = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists || now() - (snap.get("lastQueryAtMs") || 0) < 600000) return false;
        tx.update(ref, {lastQueryAtMs: now()}); return true;
      });
      if (allowed) await sync(ref.id);
    }
    return status(uid, shopId);
  }
  async function cancel(uid, shopId) {
    await owner(uid, shopId, true);
    const acc = await account(shopId).get();
    if (!acc.exists || !acc.get("orderId")) throw new HttpsError("not-found", "沒有自動續訂");
    const ref = orders.doc(acc.get("orderId"));
    const snap = await ref.get();
    const order = snap.data();
    if (!order) throw new HttpsError("not-found", "找不到付款");
    const localCancelled = await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (current.get("state") !== "pending" || current.get("launchIssuedAtMs")) return false;
      const paid = await tx.get(ledger(order).doc(`${order.id}_1`));
      if (paid.exists) return false;
      tx.update(ref, {state: "cancelled", launchHash: "", launchExpiresAtMs: 0, requiresReconcile: false, cancelledAtMs: now()});
      return true;
    });
    if (localCancelled) return status(uid, shopId);
    if (!order.recurring) throw new HttpsError("failed-precondition", "此付款已開啟綠界，請先查詢原交易狀態，不會直接標記取消");
    if (["cancelled", "completed"].includes(order.state)) return status(uid, shopId);
    if (!provider) throw new HttpsError("unavailable", "綠界尚未設定，請聯絡平台確認終止");
    if (order.state === "cancel_pending") {
      try {
        await sync(ref.id);
        const checked = await ref.get();
        if (["cancelled", "completed"].includes(checked.get("state"))) return status(uid, shopId);
      } catch (_) {/* Still attempt the requested termination if query is unavailable. */}
    }
    await ref.update({state: "cancel_pending", requiresReconcile: true, cancelRequestedAtMs: now(), nextCheckAtMs: now() + 60000});
    await provider.cancel(order); // Never claim cancellation on timeout/failure.
    await ref.update({state: "cancelled", requiresReconcile: true, nextCheckAtMs: now() + 60000, cancelledAtMs: now()});
    try {
      await sync(ref.id);
    } catch (_) {/* Recover already-paid charges via scheduled reconciliation. */}
    return status(uid, shopId);
  }
  async function reconcile(limit = 10) {
    const rows = await orders.where("requiresReconcile", "==", true)
        .where("nextCheckAtMs", "<=", now()).orderBy("nextCheckAtMs").limit(limit).get();
    const failures = [];
    for (const doc of rows.docs) {
      if (doc.get("environment") !== environment) continue;
      try {
        if (doc.get("state") === "pending" && !doc.get("launchIssuedAtMs")) {
          await doc.ref.update({nextCheckAtMs: now() + 86400000});
          continue;
        }
        await drain(doc.id);
        const prepared = await doc.ref.get();
        if (!prepared.get("requiresReconcile") || prepared.get("nextCheckAtMs") > now()) continue;
        if (prepared.get("state") === "cancel_pending") {
          // A query outage must not prevent an already-requested cancellation.
          try {
            await sync(doc.id);
          } catch (_) {/* Termination still proceeds when the query is down. */}
          const checked = await doc.ref.get();
          if (checked.get("state") === "cancel_pending") {
            await provider.cancel(checked.data());
            await doc.ref.update({state: "cancelled", requiresReconcile: true, nextCheckAtMs: now() + 1800000, cancelledAtMs: now()});
          }
        } else {
          await sync(doc.id);
        }
      } catch (_) {
        await doc.ref.update({nextCheckAtMs: now() + 1800000});
        failures.push(doc.id);
      }
    }
    return {cursor: "", failures};
  }
  return {status, checkout, launch, callback, refresh, cancel, reconcile, drain};
}
async function assertNoPlatformBilling(tx, db, shopId) {
  const acc = await tx.get(db.collection("platform_billing_accounts").doc(`production_${shopId}`));
  if (!acc.exists || !acc.get("orderId")) return;
  const order = await tx.get(db.collection("platform_billing_orders").doc(acc.get("orderId")));
  if (order.exists && (LOCKED.includes(order.get("state")) || order.get("requiresReconcile") === true)) throw new HttpsError("failed-precondition", "店家仍有平台待付款、自動續訂或取消對帳未完成，請先確認綠界已停止扣款後再刪店");
}
module.exports = {createBilling, assertNoPlatformBilling};
