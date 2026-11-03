/* eslint-disable max-len, require-jsdoc */
"use strict";
const admin = require("firebase-admin");
const {defineBoolean, defineString, defineSecret} = require("firebase-functions/params");
const {onCall, HttpsError} = require("../platform/inspection_write_guard");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {gateway} = require("./gateway");
const {createBilling} = require("./service");
const enabled = defineBoolean("PLATFORM_BILLING_ENABLED", {default: false});
const environment = defineString("PLATFORM_BILLING_ENVIRONMENT", {default: "test"});
const publicOrigin = defineString("PLATFORM_BILLING_PUBLIC_ORIGIN", {default: ""});
const merchantId = defineSecret("PLATFORM_ECPAY_MERCHANT_ID");
const hashKey = defineSecret("PLATFORM_ECPAY_HASH_KEY");
const hashIv = defineSecret("PLATFORM_ECPAY_HASH_IV");
const options = {region: "asia-east1", secrets: [merchantId, hashKey, hashIv], timeoutSeconds: 120};
function caller(request, inspectionRead = false) {
  if (!request.auth || ((request.auth.token.firebase || {}).sign_in_provider === "anonymous" && !(inspectionRead && request.auth.token.petnestInspection === true))) throw new HttpsError("unauthenticated", "請先登入店主帳號");
  return request.auth.uid;
}
function instance(withGateway) {
  const db = admin.firestore();
  const env = environment.value();
  if (!["test", "production"].includes(env)) throw new HttpsError("failed-precondition", "平台收費環境設定不正確");
  let provider = null;
  if (withGateway) {
    const origin = publicOrigin.value();
    let url;
    try {
      url = new URL(origin);
    } catch (_) {
      throw new HttpsError("failed-precondition", "請先設定平台HTTPS付款返回網址");
    }
    if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash || !["", "/"].includes(url.pathname)) throw new HttpsError("failed-precondition", "平台付款返回網址必須為HTTPS網站原點");
    const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    if (!project || !/^[a-z0-9-]+$/.test(project)) throw new HttpsError("failed-precondition", "無法確認平台付款專案");
    const base = `https://asia-east1-${project}.cloudfunctions.net`;
    provider = gateway({environment: env, merchantId: merchantId.value(), hashKey: hashKey.value(), hashIv: hashIv.value(),
      publicOrigin: url.origin, checkoutUrl: base + "/platformSubscriptionCheckout", callbackUrl: base + "/platformSubscriptionCallback", periodicUrl: base + "/platformSubscriptionPeriodicCallback"});
  }
  return createBilling({db, environment: env, enabled: enabled.value(), provider,
    stamp: () => admin.firestore.FieldValue.serverTimestamp(),
    settle: (paymentId, paymentDate, servicePeriod) => require("../sales/commercial_ops").confirmSubscriptionPayment(
        {uid: "system_ecpay_platform", enabled: true, permissions: ["manage_subscription_finance"]},
        {paymentId}, {paymentDate, servicePeriod, verifiedGateway: true}),
  });
}
exports.getPlatformBilling = onCall({region: "asia-east1", inspectionRead: true},
    (request) => instance(false).status(caller(request, true), (request.data || {}).shopId));
exports.checkoutPlatformSubscription = onCall(options, (request) => {
  const uid = caller(request);
  if (request.auth.token.email_verified !== true) throw new HttpsError("failed-precondition", "請先完成店主Email驗證再付款");
  return instance(true).checkout(uid, request.data || {});
});
exports.refreshPlatformBilling = onCall(options, (request) => instance(true).refresh(caller(request), (request.data || {}).shopId));
exports.cancelPlatformSubscription = onCall(options, (request) => instance(true).cancel(caller(request), (request.data || {}).shopId));
function callback(periodic) {
  return onRequest({...options, invoker: "public"}, async (req, res) => {
    res.set("Cache-Control", "no-store");
    if (req.method !== "POST" || !req.is("application/x-www-form-urlencoded")) {
      res.status(405).send("0|Invalid request"); return;
    }
    try {
      await instance(true).callback(req.body || {}, periodic);
      res.status(200).type("text/plain").send("1|OK");
    } catch (_) {
      // Never log request/response bodies or gateway exceptions containing them.
      console.warn("Platform subscription callback rejected or awaiting reconciliation");
      res.status(200).type("text/plain").send("0|Verification or settlement pending");
    }
  });
}
exports.platformSubscriptionCallback = callback(false);
exports.platformSubscriptionPeriodicCallback = callback(true);
exports.reconcilePlatformSubscriptions = onSchedule({...options, timeoutSeconds: 540,
  schedule: "every 30 minutes", timeZone: "Asia/Taipei"}, async () => {
  // Cancellation/reconciliation must continue even when new checkouts are disabled.
  const db = admin.firestore();
  const ref = db.collection("platform_billing_state").doc("reconcile");
  const now = Date.now();
  const lease = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const row = snap.data() || {};
    if (row.leaseUntilMs > now) return null;
    tx.set(ref, {leaseUntilMs: now + 600000}, {merge: true});
    return {cursor: row.cursor || ""};
  });
  if (!lease) return;
  try {
    const result = await instance(true).reconcile(10);
    await ref.set({cursor: result.cursor, leaseUntilMs: 0, lastRunMs: Date.now(), failedCount: result.failures.length}, {merge: true});
  } catch (_) {
    await ref.set({leaseUntilMs: 0, lastFailedAtMs: Date.now()}, {merge: true});
    console.warn("Platform subscription reconciliation needs configuration or retry");
  }
});

// A system-browser handoff: no card form or card fields ever run in our APP.
exports.platformSubscriptionCheckout = onRequest({...options, invoker: "public"}, async (req, res) => {
  const crypto = require("node:crypto");
  res.set("Cache-Control", "no-store");
  res.set("Referrer-Policy", "no-referrer");
  res.set("X-Content-Type-Options", "nosniff");
  let nonce = crypto.randomBytes(16).toString("hex");
  if (req.method === "GET") {
    res.set("Content-Security-Policy", `default-src 'none'; script-src 'nonce-${nonce}'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'`);
    res.type("html").send(`<!doctype html><meta charset="utf-8"><title>前往綠界</title><p>正在前往綠界付款；若連結已失效，請回店主方案頁重新開啟。</p><script nonce="${nonce}">const p=location.hash.slice(1).split('.');history.replaceState(null,'',location.pathname);if(p.length===2){const f=document.createElement('form');f.method='post';f.action=location.pathname;['id','token'].forEach((k,i)=>{const e=document.createElement('input');e.type='hidden';e.name=k;e.value=p[i];f.appendChild(e);});document.body.appendChild(f);f.submit();}</script>`);
    return;
  }
  if (req.method !== "POST" || !req.is("application/x-www-form-urlencoded")) {
    res.status(405).send("請從店主方案頁開啟付款"); return;
  }
  try {
    const result = await instance(true).launch((req.body || {}).id, (req.body || {}).token);
    nonce = result.nonce;
    res.set("Content-Security-Policy", `default-src 'none'; script-src 'nonce-${nonce}'; form-action https://payment.ecpay.com.tw https://payment-stage.ecpay.com.tw; frame-ancestors 'none'; base-uri 'none'`);
    res.type("html").send(result.html);
  } catch (_) {
    res.status(400).type("text/plain").send("付款連結已失效或尚未設定，請回店主方案頁重新開啟。");
  }
});
