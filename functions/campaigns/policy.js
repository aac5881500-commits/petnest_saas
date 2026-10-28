/* eslint-disable max-len, require-jsdoc */
"use strict";
const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const LIMIT = 5000;
function id(value) {
  if (typeof value !== "string" || !value || value.length > 160 || value.includes("/")) {
    throw new HttpsError("invalid-argument", "資料識別碼不正確。");
  }
  return value;
}
function permissions(shop, member, uid) {
  if (shop.ownerUid === uid) return {draft: true, send: true, view: true};
  const valid = member && member.uid === uid && member.shopId &&
    ["manager", "staff"].includes(member.role) && member.active !== false &&
    member.isActive !== false && !["disabled", "removed", "suspended"].includes(member.status);
  const keys = valid && member.permissions || {};
  return {draft: keys.manage_campaign_drafts === true || keys.send_member_campaigns === true,
    send: keys.send_member_campaigns === true,
    view: keys.view_member_campaigns === true || keys.manage_campaign_drafts === true || keys.send_member_campaigns === true};
}
function normalize(raw) {
  const title = String(raw.title || "").trim();
  const body = String(raw.body || "").trim();
  if (!title || title.length > 80 || !body || body.length > 2000) {
    throw new HttpsError("invalid-argument", "標題必填且最多 80 字，內容必填且最多 2000 字。");
  }
  if (!["shop_marketing", "shop_notice"].includes(raw.category) ||
      !["inbox", "push"].includes(raw.channel) ||
      !["all", "vip", "selected"].includes(raw.audience)) {
    throw new HttpsError("invalid-argument", "請選擇有效的通知分類、方式與對象。");
  }
  const memberIds = Array.from(new Set((Array.isArray(raw.memberIds) ? raw.memberIds : []).map(id))).sort();
  if (memberIds.length > LIMIT || raw.audience === "selected" && !memberIds.length) {
    throw new HttpsError("invalid-argument", "請選擇 1 至 5000 位會員。");
  }
  return {title, body, category: raw.category, channel: raw.channel,
    audience: raw.audience, memberIds: raw.audience === "selected" ? memberIds : [],
    announcementId: raw.announcementId ? id(raw.announcementId) : ""};
}
function memberUid(member, docId) {
  if (member.source === "admin" || member.memberSource === "admin" ||
      member.isBlacklisted === true || member.blacklisted === true || member.isBlocked === true || member.status === "deleted") return "";
  const uid = member.userId || member.uid || docId;
  if (typeof uid !== "string" || uid.includes("/") || uid.length > 128 || !uid || uid.startsWith("manual_")) return "";
  return uid;
}
function audience(rows, draft) {
  const chosen = new Set(draft.memberIds);
  const candidates = rows.filter((row) => draft.audience === "selected" ? chosen.has(row.id) :
    draft.audience === "vip" ? Array.isArray(row.data.tags) && row.data.tags.includes("vip") : true);
  if (draft.audience === "selected" && candidates.length !== chosen.size) {
    throw new HttpsError("failed-precondition", "部分會員已不屬於本店，請重新選擇。");
  }
  const uids = Array.from(new Set(candidates.map((row) => memberUid(row.data, row.id)).filter(Boolean))).sort();
  if (uids.length > LIMIT) throw new HttpsError("resource-exhausted", "單次最多 5000 位，請縮小對象範圍。");
  return {uids, selectedCount: candidates.length, excludedCount: candidates.length - uids.length};
}
function revision(draft, resolved) {
  return crypto.createHash("sha256").update(JSON.stringify({draft, uids: resolved.uids})).digest("hex");
}
module.exports = {LIMIT, id, permissions, normalize, memberUid, audience, revision};
