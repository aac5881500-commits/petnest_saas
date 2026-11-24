/* eslint-disable require-jsdoc, max-len */
const admin = require("firebase-admin");
const {onCall, HttpsError} = require("../platform/inspection_write_guard");
const {hasShopPermission} = require("../daycare/daycare_utils");
const {readWindow} = require("../platform/booking_time_test");
const {serviceTasks, canRecord} = require("./service_tasks");
function check(ok, code, text) {
  if (!ok) throw new HttpsError(code, text);
}
exports.recordBookingServiceTask = onCall({region: "asia-east1"}, async (req) => {
  check(req.auth, "unauthenticated", "請先登入");
  const {bookingId, taskId, scheduledAt, result, actualAt} = req.data || {};
  const note = String((req.data || {}).note || "").trim();
  check(typeof bookingId === "string" && bookingId && !bookingId.includes("/"), "invalid-argument", "訂單不正確");
  check(typeof taskId === "string" && taskId.length <= 1200, "invalid-argument", "待辦不正確");
  check(["done", "partial", "skipped"].includes(result) && note.length <= 1000, "invalid-argument", "請選擇執行結果，說明最多 1000 字");
  const db = admin.firestore(); const ref = db.collection("bookings").doc(bookingId);
  const original = await ref.get(); check(original.exists, "not-found", "找不到訂單");
  const shopId = original.data().shopId;
  check(await hasShopPermission(shopId, req.auth.uid, "manage_bookings"), "permission-denied", "沒有照護執行權限");
  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(ref); const b = fresh.data();
    check(b && b.shopId === shopId && canRecord(b), "failed-precondition", "僅入住中且未結算的訂單可填寫");
    const task = serviceTasks(b).find((t) => t.id === taskId);
    check(task && Date.parse(task.scheduledAt) === Date.parse(scheduledAt), "failed-precondition", "時程已變更，請重新開啟待辦");
    check(task.petId, "failed-precondition", "舊預約缺少可辨識的寵物資料，請先與店家核對");
    if (task.record) {
      check(req.data.expectedRevision != null, "already-exists", "此項已有結果，請重新開啟紀錄後修改");
      check(Number(req.data.expectedRevision) === Number(task.record.revision || 0),
          "aborted", "紀錄已由其他人更新，請重新開啟後修改");
    } else {
      check(req.data.expectedRevision == null, "aborted", "紀錄已變更，請重新開啟");
    }
    const actual = new Date(actualAt); const now = Date.now();
    const testWindow = await readWindow(tx, db, bookingId, b, now);
    const start = [b.actualStartAt, b.checkInAt, b.checkedInAt, b.scheduledStartAt, b.startAt, b.startDate]
        .filter((value) => value != null && value !== "")
        .map((value) => {
          if (typeof value.toDate === "function") return value.toDate();
          if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
            return new Date(value + "T00:00:00+08:00");
          }
          return new Date(value);
        })
        .find((value) => Number.isFinite(value.getTime()));
    check(typeof actualAt === "string" && Number.isFinite(actual.getTime()), "invalid-argument", "請選擇有效的實際時間");
    check(result === "skipped" || start, "failed-precondition", "缺少有效的入住時間，請先核對訂單資料");
    // The result form records hours and minutes. A timestamp later in that
    // same minute must not prevent staff from recording the result.
    check(result === "skipped" || Math.floor(actual.getTime() / 60000) >= Math.floor(start.getTime() / 60000),
        "invalid-argument", "實際時間早於入住時間，請修改時間");
    check(testWindow || actual.getTime() <= now + 60000,
        "invalid-argument", "實際時間晚於現在，請修改時間");
    check(testWindow || result === "skipped" || Date.parse(task.scheduledAt) <= actual.getTime() + 30 * 60000, "failed-precondition", "尚未到服務時間，若取消請填寫未執行原因");
    const record = {revision: Number(task.record?.revision || 0) + 1, scheduledAt: task.scheduledAt, actualAt: actual.toISOString(), result, note,
      by: req.auth.uid, byName: String((req.auth.token || {}).name || "店家人員").slice(0, 100),
      recordedAt: new Date(now).toISOString(), title: task.title, petId: task.petId, ...(testWindow ? {timeTest: testWindow} : {})};
    if (task.record) {
      tx.set(db.collection(`bookings/${bookingId}/careServiceCorrections`).doc(
          `${task.id}_${record.revision}`), {
        taskId: task.id, previous: task.record, replacement: record,
      });
    }
    const records = {...(b.careServiceRecords || {}), [task.id]: record};
    check(Buffer.byteLength(JSON.stringify(records), "utf8") < 150000, "resource-exhausted", "服務紀錄已達上限");
    const label = {done: "已完成", partial: "部分完成", skipped: "未執行"}[result];
    const text = `${testWindow ? "【測試訂單】" : ""}預約服務已更新（${label}），請至訂單「服務與用藥」查看結果與說明。`;
    if (b.userId) {
      const data = {type: "booking_status", section: "care",
        careKind: "service", bookingId, shopId};
      tx.set(db.collection("notifications").doc(
          `care_service_${bookingId}_${task.id}_${record.revision}`), {
        userId: b.userId, title: "專屬服務紀錄已更新", body: text,
        ...data, data,
        source: "system", category: "transactional", isMandatory: true,
        status: "active", isRead: false, readAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    tx.update(ref, {careServiceRecords: records,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    return {ok: true};
  });
});
