/* eslint-disable max-len, require-jsdoc */
"use strict";
const {onCall, HttpsError} = require("../platform/inspection_write_guard");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const policy = require("./policy");
const linePreparation = require("../line/preparation");

function createCampaignFunctions({admin, customerPushAllowed}) {
  const db = admin.firestore();
  const stamp = () => admin.firestore.FieldValue.serverTimestamp();
  const campaigns = db.collection("shop_campaigns");
  async function actor(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "請先登入。");
    const shopId = policy.id(request.data.shopId);
    const uid = request.auth.uid;
    const [shopSnap, memberSnap] = await Promise.all([
      db.collection("shops").doc(shopId).get(),
      db.collection("shop_members").doc(`${shopId}_${uid}`).get(),
    ]);
    const shop = shopSnap.data();
    if (!shop || shop.deletionState === "deleting") throw new HttpsError("not-found", "找不到店家。");
    const member = memberSnap.data();
    if (member && member.shopId !== shopId) throw new HttpsError("permission-denied", "店家身分不符。");
    const can = policy.permissions(shop, member, uid);
    if (!can.view) throw new HttpsError("permission-denied", "沒有會員推廣與通知權限。");
    return {shopId, uid, shop, can};
  }
  async function members(shopId) {
    const snap = await db.collection("shops").doc(shopId).collection("members").limit(10001).get();
    if (snap.size > 10000) throw new HttpsError("resource-exhausted", "會員數超過第一版上限，請聯絡管理員。");
    return snap.docs.map((doc) => ({id: doc.id, data: doc.data()}));
  }
  async function resolve(shopId, draft) {
    if (draft.announcementId) {
      const a = await db.collection("shops").doc(shopId).collection("announcements").doc(draft.announcementId).get();
      if (!a.exists || a.data().isPublished !== true) {
        throw new HttpsError("failed-precondition", "公告已下架或刪除，請重新選擇已發布公告。");
      }
    }
    const resolved = policy.audience(await members(shopId), draft);
    // A shop member cache alone is not proof of an app account.
    const valid = [];
    for (let i = 0; i < resolved.uids.length; i += 100) {
      const result = await admin.auth().getUsers(resolved.uids.slice(i, i + 100).map((uid) => ({uid})));
      valid.push(...result.users.filter((user) => !user.disabled).map((user) => user.uid));
    }
    resolved.excludedCount += resolved.uids.length - valid.length;
    resolved.uids = valid.sort();
    const validUids = new Set(resolved.uids);
    const uniqueRecipients = new Map();
    for (const row of resolved.recipients) {
      if (validUids.has(row.uid)) uniqueRecipients.set(row.uid, row);
    }
    resolved.recipients = [...uniqueRecipients.values()];
    resolved.restrictedCount = resolved.recipients.filter((row) => row.restricted).length;
    return resolved;
  }
  const summarize = (doc) => {
    const d = doc.data();
    return {id: doc.id, title: d.title, body: d.body, purpose: d.purpose || "", category: d.category, channel: d.channel,
      audience: d.audience, memberIds: d.memberIds || [], announcementId: d.announcementId || "",
      status: d.status, version: d.version || 0, sentBy: d.sentBy || "", senderName: d.senderName || "",
      createdAt: d.createdAt && d.createdAt.toMillis(), updatedAt: d.updatedAt && d.updatedAt.toMillis(),
      recipientCount: d.recipientCount || 0, excludedCount: d.excludedCount || 0,
      counts: d.counts || {}, revision: d.revision || "", error: d.error || ""};
  };
  const manageShopCampaign = onCall({region: "asia-east1", timeoutSeconds: 120}, async (request) => {
    const ctx = await actor(request);
    const data = request.data;
    const action = data.action;
    if (action === "linePreparation" || action === "saveLinePreparation") {
      const owner = ctx.shop.ownerUid === ctx.uid;
      const preparation = db.collection("shop_line_preparations").doc(ctx.shopId);
      if (action === "saveLinePreparation") {
        if (!owner) throw new HttpsError("permission-denied", "LINE 串接準備資料僅限店主修改。");
        const configuration = linePreparation.normalizePreparation(data.configuration);
        if (!Number.isInteger(data.version) || data.version < 0) throw new HttpsError("invalid-argument", "請重新讀取準備資料。");
        await db.runTransaction(async (tx) => {
          const before = await tx.get(preparation);
          const version = before.exists ? before.data().version || 0 : 0;
          if (version !== data.version) throw new HttpsError("aborted", "資料已在其他視窗更新，請重新讀取後再儲存。");
          tx.set(preparation, {...configuration, schemaVersion: 1, phase: "preparation_only",
            version: version + 1, updatedBy: ctx.uid, updatedAt: stamp()});
        });
      }
      const record = await preparation.get();
      return {...linePreparation.preparationStatus(record.data() || {}), canEdit: owner};
    }
    if (action === "bootstrap") {
      const docs = await campaigns.where("shopId", "==", ctx.shopId).orderBy("updatedAt", "desc").limit(100).get();
      return {permissions: ctx.can, recentLimit: 100, campaigns: docs.docs.map(summarize).sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0)),
        limit: policy.LIMIT};
    }
    if (action === "members") {
      if (!ctx.can.draft) throw new HttpsError("permission-denied", "沒有選擇收件對象權限。");
      return {accountNotices: true, members: (await members(ctx.shopId)).map((row) => ({id: row.id,
        name: String(row.data.name || "未命名會員"), phone: String(row.data.phone || ""),
        vip: Array.isArray(row.data.tags) && row.data.tags.includes("vip"),
        reachable: !!policy.memberUid(row.data, row.id), restricted: policy.restricted(row.data),
        accountReachable: !!policy.memberUid(row.data, row.id, {purpose: "member_account", category: "shop_notice", audience: "selected"})}))};
    }
    const ref = campaigns.doc(policy.id(data.campaignId));
    if (action === "detail") {
      const doc = await ref.get();
      if (!doc.exists || doc.data().shopId !== ctx.shopId) throw new HttpsError("not-found", "找不到發送紀錄。");
      const deliveries = await ref.collection("deliveries").limit(100).get();
      return {campaign: summarize(doc), deliveries: deliveries.docs.map((d) => ({
        uid: d.id, inbox: d.data().inbox, push: d.data().push, reason: d.data().reason || ""})),
      truncated: deliveries.size === 100};
    }
    if (!ctx.can.draft) throw new HttpsError("permission-denied", "沒有建立推廣草稿權限。");
    if (action === "save" || action === "preview") {
      const draft = policy.normalize(data.draft || {});
      const resolved = action === "preview" ? await resolve(ctx.shopId, draft) : null;
      const rev = resolved ? policy.revision(draft, resolved) : "";
      await db.runTransaction(async (tx) => {
        const old = await tx.get(ref);
        if (old.exists && (old.data().shopId !== ctx.shopId || old.data().status !== "draft")) {
          throw new HttpsError("failed-precondition", "此內容已送出或無法編輯。");
        }
        const version = old.exists ? old.data().version || 0 : 0;
        if (old.exists && data.version !== version) throw new HttpsError("aborted", "草稿已在其他視窗更新，請重新載入。");
        tx.set(ref, {...draft, shopId: ctx.shopId, status: "draft", updatedBy: ctx.uid,
          version: version + 1, revision: rev, updatedAt: stamp(),
          recipientCount: resolved ? resolved.uids.length : 0,
          excludedCount: resolved ? resolved.excludedCount : 0,
          ...(!old.exists ? {createdAt: stamp(), createdBy: ctx.uid} : {})});
      });
      const doc = await ref.get();
      return {campaign: {...summarize(doc), version: doc.data().version},
        preview: resolved ? {count: resolved.uids.length, excluded: resolved.excludedCount, revision: rev,
          recipients: resolved.recipients.slice(0, 20).map(({memberId, name, restricted}) => ({memberId, name, restricted})),
          restrictedCount: resolved.restrictedCount} : null};
    }
    if (action === "send") {
      if (!ctx.can.send) throw new HttpsError("permission-denied", "沒有正式發送權限，請由店主授權。");
      const snap = await ref.get();
      if (!snap.exists || snap.data().shopId !== ctx.shopId) throw new HttpsError("not-found", "找不到草稿。");
      if (snap.data().status !== "draft") return {campaign: summarize(snap), duplicate: true};
      const draft = policy.normalize(snap.data());
      const resolved = await resolve(ctx.shopId, draft);
      const rev = policy.revision(draft, resolved);
      if (!resolved.uids.length || rev !== data.revision || rev !== snap.data().revision) {
        throw new HttpsError("failed-precondition", "會員或內容已變動，或沒有可通知會員，請重新預覽。");
      }
      await db.runTransaction(async (tx) => {
        const current = await tx.get(ref);
        if (current.data().status !== "draft") return;
        if (current.data().revision !== rev || current.data().version !== snap.data().version) {
          throw new HttpsError("aborted", "草稿已更新，請重新預覽。");
        }
        tx.update(ref, {status: "queued", recipientUids: resolved.uids,
          recipientCount: resolved.uids.length, excludedCount: resolved.excludedCount,
          shopName: String(ctx.shop.name || "店家"), sentBy: ctx.uid,
          senderName: String(request.auth.token.name || request.auth.token.email || ctx.uid),
          sentAt: stamp(), updatedAt: stamp(), counts: {}});
      });
      return {campaign: summarize(await ref.get())};
    }
    throw new HttpsError("invalid-argument", "不支援的操作。");
  });

  async function push(uid, campaign) {
    if (campaign.channel !== "push") return {push: "not_requested"};
    const global = await db.collection("users").doc(uid).collection("notification_settings").doc("global").get();
    if (!customerPushAllowed({category: campaign.category, isMandatory: false}, global.data() || {}, campaign.shopId)) {
      return {push: "opted_out"};
    }
    const docs = await db.collection("users").doc(uid).collection("fcm_tokens").get();
    const tokens = docs.docs.filter((doc) => doc.data().enabled !== false).map((doc) => doc.id);
    if (!tokens.length) return {push: "no_token"};
    let accepted = 0;
    let failed = 0;
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const result = await admin.messaging().sendEachForMulticast({tokens: chunk,
        notification: policy.accountNotice(campaign) ? {title: `${campaign.shopName}・會員服務通知`, body: "您有一則會員服務訊息，請開啟 App 查看完整內容。"} :
          {title: campaign.title, body: campaign.body.slice(0, 150)},
        data: {type: "shop_campaign", shopId: campaign.shopId, campaignId: campaign.id,
          shopName: campaign.shopName, source: "shop", category: campaign.category,
          isMandatory: "false", noticeKind: campaign.announcementId ? "announcement" : campaign.category === "shop_notice" ? "service_change" : "campaign"}});
      accepted += result.successCount; failed += result.failureCount;
      await Promise.all(result.responses.map((response, index) => {
        const code = response.error && response.error.code;
        return ["messaging/registration-token-not-registered", "messaging/invalid-registration-token"].includes(code) ?
          db.collection("users").doc(uid).collection("fcm_tokens").doc(chunk[index]).delete() : Promise.resolve();
      }));
    }
    return {push: accepted ? failed ? "partial" : "accepted" : "failed"};
  }
  async function process(ref) {
    const owner = require("node:crypto").randomUUID();
    const claimed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref); const d = snap.data();
      if (!d || !["queued", "processing"].includes(d.status) || (d.leaseUntil || 0) > Date.now()) return null;
      tx.update(ref, {status: "processing", leaseOwner: owner, leaseUntil: Date.now() + 8 * 60000});
      return {...d, id: ref.id};
    });
    if (!claimed) return;
    try {
      // Bounded chunks; inbox records and per-member claims are atomic.
      const targets = claimed.recipientUids || [];
      const cursor = claimed.cursor || 0;
      for (const uid of targets.slice(cursor, cursor + 100)) {
        const receipt = ref.collection("deliveries").doc(uid);
        const allowed = await db.runTransaction(async (tx) => {
          const [job, existing] = await Promise.all([tx.get(ref), tx.get(receipt)]);
          if (job.data().leaseOwner !== owner) return false;
          if (existing.exists) return false;
          const note = db.collection("notifications").doc(`campaign_${ref.id}_${uid}`);
          const member = await tx.get(db.collection("shops").doc(claimed.shopId).collection("members").where("userId", "==", uid).limit(1));
          const canonical = await tx.get(db.collection("shops").doc(claimed.shopId).collection("members").doc(uid));
          const data = canonical.exists ? canonical.data() : !member.empty ? member.docs[0].data() : null;
          if (!data || !policy.memberUid(data, uid, claimed)) {
            tx.create(receipt, {inbox: "skipped", push: "not_requested", reason: "會員已移除或不符合通知資格", createdAt: stamp()});
            return false;
          }
          const payload = {type: "shop_campaign", shopId: claimed.shopId, shopName: claimed.shopName,
            campaignId: ref.id, purpose: claimed.purpose || "", announcementId: claimed.announcementId, noticeKind: claimed.announcementId ? "announcement" :
              claimed.category === "shop_notice" ? "service_change" : "campaign"};
          tx.create(note, {userId: uid, title: claimed.title, body: claimed.body, type: "shop_campaign",
            shopId: claimed.shopId, shopName: claimed.shopName, source: "shop", category: claimed.category,
            isMandatory: false, isRead: false, readAt: null, status: "active", data: payload, createdAt: stamp()});
          tx.create(receipt, {inbox: "created", push: "attempting", createdAt: stamp()});
          return true;
        });
        if (allowed) {
          let result;
          try {
            result = await push(uid, claimed);
          } catch (_) {
            result = {push: "unknown"};
          }
          await receipt.update({...result, updatedAt: stamp()});
        }
        await db.runTransaction(async (tx) => {
          const current = await tx.get(ref);
          if (current.data().leaseOwner !== owner) throw new Error("lease changed");
          tx.update(ref, {leaseUntil: Date.now() + 8 * 60000});
        });
      }
      if (cursor + 100 < targets.length) {
        await db.runTransaction(async (tx) => {
          const current = await tx.get(ref);
          if (current.data().leaseOwner === owner) tx.update(ref, {status: "queued", cursor: cursor + 100, leaseUntil: 0, updatedAt: stamp()});
        });
        return;
      }
      const receipts = await ref.collection("deliveries").get();
      const counts = {inbox: 0, skipped: 0, accepted: 0, partial: 0, opted_out: 0, no_token: 0, failed: 0, unknown: 0, not_requested: 0};
      for (const doc of receipts.docs) {
        const d = doc.data();
        counts[d.inbox === "created" ? "inbox" : "skipped"]++;
        const state = d.push === "attempting" ? "unknown" : d.push;
        counts[state] = (counts[state] || 0) + 1;
      }
      await db.runTransaction(async (tx) => {
        const job = await tx.get(ref);
        if (job.data().leaseOwner === owner) tx.update(ref, {counts, status: "completed", leaseUntil: 0, updatedAt: stamp()});
      });
    } catch (error) {
      await db.runTransaction(async (tx) => {
        const current = await tx.get(ref);
        if (current.data().leaseOwner === owner) {
          tx.update(ref, {leaseUntil: 0,
            error: "部分處理中斷，系統將續處理；已建立通知不會重複建立。", updatedAt: stamp()});
        }
      });
      console.error("Campaign processing interrupted", ref.id, error.message);
    }
  }
  const deliverShopCampaign = onDocumentWritten({document: "shop_campaigns/{campaignId}", region: "asia-east1", timeoutSeconds: 540}, async (event) => {
    const after = event.data && event.data.after;
    if (after && after.exists && after.data().status === "queued") await process(after.ref);
  });
  const resumeShopCampaigns = onSchedule({schedule: "every 5 minutes", region: "asia-east1", timeoutSeconds: 540}, async () => {
    const jobs = await campaigns.where("status", "in", ["queued", "processing"]).limit(20).get();
    for (const job of jobs.docs) await process(job.ref);
  });
  const result = {manageShopCampaign, deliverShopCampaign, resumeShopCampaigns};
  Object.defineProperty(result, "processForTest", {value: process});
  return result;
}
module.exports = {createCampaignFunctions};
