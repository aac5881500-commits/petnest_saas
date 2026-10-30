"use strict";
const {defineSecret} = require("firebase-functions/params");
const {HttpsError} = require("firebase-functions/v2/https");
// Reuse the project's configured transactional mail account, not its deletion
// authorization grants. Inspection challenges live in separate collections.
const host = defineSecret("SHOP_DELETION_SMTP_HOST");
const from = defineSecret("SHOP_DELETION_SMTP_FROM");
const user = defineSecret("SHOP_DELETION_SMTP_USER");
const pass = defineSecret("SHOP_DELETION_SMTP_PASS");
/**
 * Deliver a code to the server-selected verified root mailbox.
 * @param {Object} message Email fields.
 */
async function sendInspectionEmail(message) {
  const config = {host: host.value(), from: from.value(),
    user: user.value(), pass: pass.value()};
  if (Object.values(config).some((v) => !v)) {
    throw new HttpsError("failed-precondition", "尚未設定查核驗證碼寄信服務。");
  }
  const transport = require("nodemailer").createTransport({
    host: config.host,
    port: Number(process.env.SHOP_DELETION_SMTP_PORT || 587),
    secure: process.env.SHOP_DELETION_SMTP_SECURE === "true",
    auth: {user: config.user, pass: config.pass},
    connectionTimeout: 10000, greetingTimeout: 10000, socketTimeout: 20000,
  });
  try {
    const result = await transport.sendMail({from: config.from, ...message});
    if (!result.accepted || result.accepted.length === 0) {
      throw new Error("Mail not accepted");
    }
  } finally {
    transport.close();
  }
}
module.exports = {sendInspectionEmail, secrets: [host, from, user, pass]};
