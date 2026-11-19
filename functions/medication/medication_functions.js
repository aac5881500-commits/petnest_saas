/* eslint-disable require-jsdoc, max-len */
const admin = require("firebase-admin");
const {onCall, HttpsError} = require("../platform/inspection_write_guard");
const {hasShopPermission} = require("../daycare/daycare_utils");
const logic = require("./medication_logic");
const {settlementFields} = require("../bookings/booking_settlement_math");
const region = "asia-east1";

exports.quoteBookingMedication = onCall({region}, async (req) => {
  assert(req.auth, "unauthenticated", "請先登入");
  const data = req.data || {}; const shopId = String(data.shopId || "");
  assert(shopId && !shopId.includes("/"), "invalid-argument", "店家不正確");
  const snap = await admin.firestore().collection("shops").doc(shopId).get();
  assert(snap.exists, "not-found", "找不到店家");
  try {
    const value = logic.initial(data.request, {shopId, petIds: data.petIds, startDate: data.startDate, endDate: data.endDate}, (snap.data() || {}).medicationSetting, req.auth.uid);
    return value ? {estimate: value.estimate, tasks: value.tasks, issues: value.issues} : {estimate: {plannedCount: 0, amount: 0}, tasks: [], issues: []};
  } catch (e) {
    throw new HttpsError("invalid-argument", e.message);
  }
});

function assert(ok, code, message) {
  if (!ok) throw new HttpsError(code, message);
}
async function permission(shopId, uid, key) {
  assert(await hasShopPermission(shopId, uid, key), "permission-denied", "沒有操作用藥協助的權限");
}
exports.saveMedicationSetting = onCall({region}, async (req) => {
  assert(req.auth, "unauthenticated", "請先登入");
  const shopId = String(req.data.shopId || "");
  assert(shopId && !shopId.includes("/"), "invalid-argument", "店家不正確");
  await permission(shopId, req.auth.uid, "manage_booking_settings");
  try {
    const raw = {...req.data.setting};
    if (["day", "night"].includes(raw.mode)) {
      raw.mode = "day"; raw.dayRule = "service_dates";
    }
    const setting = logic.settings(raw);
    await admin.firestore().collection("shops").doc(shopId).update({medicationSetting: setting,
      medicationSettingUpdatedAt: admin.firestore.FieldValue.serverTimestamp(), medicationSettingUpdatedBy: req.auth.uid});
    return {ok: true};
  } catch (e) {
    throw new HttpsError("failed-precondition", e.message);
  }
});
exports.manageBookingMedication = onCall({region}, async (req) => {
  assert(req.auth, "unauthenticated", "請先登入");
  const data = req.data || {}; const uid = req.auth.uid;
  const bookingId = String(data.bookingId || "");
  assert(bookingId && !bookingId.includes("/"), "invalid-argument", "訂單不正確");
  const db = admin.firestore(); const ref = db.collection("bookings").doc(bookingId);
  const before = await ref.get();
  assert(before.exists, "not-found", "找不到訂單");
  const original = before.data(); const action = String(data.action || "");
  const customer = ["accept", "reject"].includes(action);
  if (customer) assert(original.userId === uid, "permission-denied", "只有訂購人可確認用藥安排");
  else await permission(original.shopId, uid, "manage_bookings");
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref); const booking = snap.data();
      assert(booking && booking.shopId === original.shopId && booking.userId === original.userId, "failed-precondition", "訂單已變動，請重新整理");
      assert(!["cancelled", "completed"].includes(booking.status) && !booking.settlementConfirmed && !booking.settlementLocked && !booking.settledAt, "failed-precondition", "訂單已取消或結算，無法再變更用藥");
      const m = booking.medication;
      if (action === "prepareLegacy") {
        if (m) return {ok: true};
        const raw = booking.medicationRequest;
        assert(raw && typeof raw === "object", "failed-precondition", "這筆訂單沒有原始用藥申請");
        assert(raw.expectedAdvanceAmount == null || raw.expectedAdvanceAmount === 0,
            "failed-precondition", "舊訂單有預收金額待核對，請先確認帳務");
        const shop = await tx.get(db.collection("shops").doc(booking.shopId));
        const setting = (shop.data() || {}).medicationSetting;
        assert(setting && setting.enabled === true, "failed-precondition", "店家未開啟用藥協助");
        const initial = logic.initial(raw, booking, setting, booking.userId);
        assert(initial, "failed-precondition", "原始用藥申請缺少可確認的內容");
        tx.update(ref, {
          medication: {...initial, advanceAmount: 0},
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {ok: true};
      }
      assert(m && !m.finalized, "failed-precondition", "沒有待處理用藥，或用藥費已結算");
      assert(Number(data.revision) === m.revision, "aborted", "用藥資料已被更新，請重新整理後再操作");
      if (action === "previewFinal") {
        assert(m.state === "confirmed", "failed-precondition", "請先完成雙方確認");
        const result = logic.quote(m.request, m.setting, m.tasks, booking, true);
        return {ok: true, ...result, agreedAmount: m.agreedAmount == null ? null : m.agreedAmount, revision: m.revision};
      }
      const now = new Date().toISOString();
      const actorName = String((req.auth.token || {}).name || (customer ? "訂購人" : "店家人員")).slice(0, 100);
      const history = (m.history || []).slice();
      assert(history.length < 600, "resource-exhausted", "用藥紀錄已達上限，請聯繫管理員");
      let next = {...m}; let patch = {};
      const note = String(data.note || "").trim().slice(0, 1000);
      if (["propose", "confirmAtArrival"].includes(action)) {
        const atArrival = action === "confirmAtArrival";
        if (atArrival) {
          assert(booking.serviceType !== "daycare", "failed-precondition", "到店核對用於住宿訂單");
          assert(["confirmed", "checked_in"].includes(booking.status), "failed-precondition", "請先確認住宿訂單，再儲存到店核對的用藥安排");
        }
        assert(["pending_shop", "pending_customer", "declined", "cancelled", "confirmed"].includes(m.state) && !m.tasks.some((t) => t.result !== "pending"), "failed-precondition", "已確認或已開始的用藥安排不可覆寫");
        const request = logic.validateRequest(data.request || m.request, booking, m.setting, booking.userId, {allowMissingDetails: atArrival});
        assert(request, "invalid-argument", "請至少保留一筆藥品");
        const built = logic.plan(request, m.setting);
        assert(!request.medicines.some((x) => x.schedule === "custom"), "failed-precondition", "請先將其他安排改成明確時間");
        if (built.tasks.some((t) => t.outside)) assert(data.allowOutside === true && note, "failed-precondition", "超出照護時段，請明確勾選同意配合並填寫說明");
        const dated = (m.request.preferences || []).filter((entry) => entry.dates);
        if (dated.length) {
          const requested = new Set(dated.flatMap((entry) => entry.dates.flatMap((day) =>
            day.times.map((time) => JSON.stringify([entry.petId, day.date, time, entry.types[0]])))));
          const medicinesById = new Map(request.medicines.map((medicine) => [medicine.id, medicine]));
          const actual = new Set(built.tasks.flatMap((task) => {
            const taipei = new Date(Date.parse(task.scheduledAt) + 8 * 3600000).toISOString();
            return task.medicineIds.map((id) => JSON.stringify([
              task.petId, taipei.slice(0, 10), taipei.slice(11, 16), medicinesById.get(id).type,
            ]));
          }));
          const changed = actual.size !== requested.size || [...actual].some((at) => !requested.has(at));
          assert(atArrival || !changed || note, "failed-precondition", "安排與客人選擇的類型、日期或時間不同，請填寫調整說明");
        }
        const estimate = logic.quote(request, m.setting, built.tasks, booking);
        let agreedAmount = null;
        if (estimate.manual) {
          const amount = Number(data.agreedAmount);
          assert(data.agreedAmount != null && Number.isInteger(amount) && amount >= 0 && amount <= 1000000 && note, "invalid-argument", "特殊報價須填寫總價與說明");
          agreedAmount = amount;
        }
        history.push({action, at: now, by: uid, note, previousRequest: m.request,
          previousEstimate: m.estimate, agreedAmount});
        next = {...next, ...built,
          request: {...request, ...(m.request.preferences ? {preferences: m.request.preferences} : {})},
          estimate, agreedAmount, proposalNote: note, state: atArrival ? "confirmed" : "pending_customer"};
        if (atArrival) next.confirmedAt = now;
      } else if (action === "accept") {
        assert(m.state === "pending_customer", "failed-precondition", "目前沒有待確認提案");
        next.state = "confirmed";
        next.confirmedAt = now;
        history.push({action, at: now, by: uid});
      } else if (action === "reject") {
        assert(m.state === "pending_customer", "failed-precondition", "目前沒有待確認提案");
        assert(note, "invalid-argument", "請填寫未接受原因");
        next.state = "pending_shop";
        history.push({action, at: now, by: uid, note});
      } else if (action === "decline" || action === "cancel") {
        assert(note, "invalid-argument", "請填寫原因");
        assert(!m.tasks.some((t) => t.result !== "pending"), "failed-precondition", "已有執行紀錄，不可取消整份用藥，請逐筆記錄未執行原因");
        next.state = action === "decline" ? "declined" : "cancelled";
        history.push({action, at: now, by: uid, note});
      } else if (action === "record") {
        assert(m.state === "confirmed" && booking.status === "checked_in", "failed-precondition", "僅入住中且雙方已確認的需求可記錄");
        assert(logic.RESULTS.includes(data.result), "invalid-argument", "執行結果不正確");
        if (data.result !== "done") assert(note, "invalid-argument", "未完成或拌食待確認時請填寫說明");
        const index = m.tasks.findIndex((t) => t.id === data.taskId);
        assert(index >= 0, "not-found", "找不到用藥待辦");
        const task = m.tasks[index];
        assert(!task.finished && ["pending", "mixed", "partial"].includes(task.result), "failed-precondition", "此項已記錄最終結果，請勿重複執行");
        assert(data.result !== "mixed" || task.medicineIds.every((id) => m.request.medicines.find((x) => x.id === id).mix), "invalid-argument", "只有全部採拌食的待辦可記為待確認食用");
        const actual = new Date(data.actualAt);
        assert(Number.isFinite(actual.getTime()) && actual.getTime() <= Date.now() + 60000 && actual >= new Date(booking.checkInAt && booking.checkInAt.toDate ? booking.checkInAt.toDate() : m.request.careStart), "invalid-argument", "實際時間不得在入住前或未來");
        assert(new Date(task.scheduledAt).getTime() <= Date.now() + 30 * 60000 || data.result === "skipped" || (data.medicineResults && Object.values(data.medicineResults).length > 0 && Object.values(data.medicineResults).every((v) => v === "skipped")), "failed-precondition", "尚未到執行時間；若已不需執行請記錄未執行及原因");
        const medicineResults = {};
        for (const id of task.medicineIds) {
          const value = data.medicineResults ? data.medicineResults[id] : data.result;
          assert(logic.RESULTS.includes(value), "invalid-argument", "請記錄每項藥品的執行結果");
          assert(value !== "mixed" || m.request.medicines.find((x) => x.id === id).mix, "invalid-argument", "只有可拌食藥品可標記待確認食用");
          if (value !== "done") assert(note, "invalid-argument", "非完成結果須填寫說明");
          const previous = task.medicineResults && task.medicineResults[id];
          assert(!["done", "failed", "skipped"].includes(previous) || previous === value, "failed-precondition", "已記錄最終結果的藥品不得重新給藥或覆寫");
          medicineResults[id] = value;
        }
        const values = Object.values(medicineResults);
        const result = values.every((v) => v === values[0]) ? values[0] : "partial";
        const finished = values.every((v) => ["done", "failed", "skipped"].includes(v));
        if (data.medicineDetails != null) {
          const details = data.medicineDetails;
          assert(details && typeof details === "object" && !Array.isArray(details) &&
            Object.keys(details).every((id) => task.medicineIds.includes(id)),
          "invalid-argument", "只能補填本次用藥的藥品資料");
          next.request = {...m.request, medicines: m.request.medicines.map((medicine) => {
            if (!Object.hasOwn(details, medicine.id)) return medicine;
            const entry = details[medicine.id];
            assert(entry && typeof entry === "object" && !Array.isArray(entry),
                "invalid-argument", "藥品資料格式不正確");
            const updated = {...medicine};
            for (const [field, limit] of [["name", 100], ["dose", 100], ["instruction", 1000]]) {
              if (!Object.hasOwn(entry, field)) continue;
              const value = entry[field];
              assert(typeof value === "string" && value.trim().length <= limit,
                  "invalid-argument", "藥品資料格式或長度不正確");
              updated[field] = value.trim();
            }
            return updated;
          })};
        }
        next.tasks = m.tasks.slice();
        const medicineDetailsSnapshot = Object.fromEntries(
            next.request.medicines.filter((medicine) => task.medicineIds.includes(medicine.id))
                .map(({id, name, dose, instruction}) => [id,
                  ["done", "failed", "skipped"].includes(task.medicineResults?.[id]) && task.medicineDetailsSnapshot?.[id] ||
                  {name: name || "", dose: dose || "", instruction: instruction || ""}]));
        next.tasks[index] = {...task, result, medicineResults, medicineDetailsSnapshot, finished, actualAt: actual.toISOString(), by: uid, byName: actorName, note};
        history.push({action, at: now, by: uid, taskId: task.id, previousResult: task.result, result, medicineResults, actualAt: actual.toISOString(), note});
      } else if (action === "finalize") {
        assert(m.state === "confirmed", "failed-precondition", "請先完成雙方確認");
        assert(["checked_in", "checked_out"].includes(booking.status), "failed-precondition", "僅入住或退房中的訂單可結算");
        const final = logic.quote(m.request, m.setting, m.tasks, booking, true);
        let amount = final.amount;
        if (m.agreedAmount != null) {
          amount = Number(data.finalAmount);
          assert(Number.isInteger(amount) && amount >= 0 && amount <= m.agreedAmount && note, "invalid-argument", "請填寫結算說明，金額不得超過客人確認的報價");
        }
        assert(Number.isInteger(amount), "failed-precondition", "費用須先報價並取得客人確認");
        assert(final.units !== 0 || amount === 0, "invalid-argument", "依已確認規則沒有可計費服務，最終用藥費應為零");
        const extras = (booking.extraCharges || []).filter((x) => x.id !== "medication");
        if (amount) extras.push({id: "medication", type: "medication", title: "用藥協助", name: "用藥協助", amount, note: note || "依已確認規則及執行紀錄結算", createdAt: now, operatorUid: uid});
        patch = {quotedTotalPrice: booking.quotedTotalPrice == null ? Number(booking.totalPrice || 0) : booking.quotedTotalPrice, extraCharges: extras};
        next = {...next, finalized: true, finalAmount: amount, finalizedAt: now, finalQuote: final};
        history.push({action, at: now, by: uid, amount, note});
      } else throw new HttpsError("invalid-argument", "不支援的操作");
      if (m.advanceAmount > 0 && ["finalize", "decline", "cancel"].includes(action)) {
        const updated = {...booking, ...patch, medication: next};
        const fields = settlementFields(updated);
        patch = {...patch, totalPrice: fields.totalPrice,
          totalPayableAmount: fields.totalPayableAmount, totalAmount: fields.totalAmount,
          remainingAmount: fields.remainingAmount, refundDueAmount: fields.refundDueAmount};
      }
      history.filter((h) => !h.byName && h.by === uid).forEach((h) => {
        h.byName = actorName;
      });
      next.history = history;
      assert(Buffer.byteLength(JSON.stringify(next), "utf8") < 750000, "resource-exhausted", "用藥資料接近容量上限，請減少說明或分段安排");
      next.revision = m.revision + 1;
      const notice = {
        confirmAtArrival: "店家已登記到店核對的用藥安排，請至訂單「服務與用藥」查看。",
        propose: "用藥安排與費用已提出，請開啟訂單確認。",
        accept: "客人已同意用藥安排與費用。",
        reject: "客人提出用藥調整需求，請開啟訂單處理。",
        decline: "店家無法提供本次用藥協助，請查看原因並確認住宿安排。",
        cancel: "本次用藥協助已取消，請查看訂單確認。",
        finalize: "用藥費已整理並帶入退房結算，請查看訂單明細。",
      }[action] || (action === "record" && next.tasks.some((t) => t.id === data.taskId && t.result !== "done") ? "用藥協助有待確認或未完成事項，請查看訂單紀錄。" : action === "record" ? "用藥結果已更新，請至訂單「服務與用藥」查看實際時間與紀錄。" : "");
      if (notice) {
        const senderType = customer ? "customer" : "shop";
        const message = db.collection(`bookings/${bookingId}/messages`).doc(`medication_${next.revision}`);
        tx.set(message, {bookingId, senderId: uid, senderType, text: notice, createdAt: admin.firestore.FieldValue.serverTimestamp(), source: "medication"});
        patch.lastMessageText = notice;
        patch.lastMessageSenderType = senderType;
        patch.lastMessageAt = admin.firestore.FieldValue.serverTimestamp();
        const unreadKey = customer ? "shopUnreadMessageCount" : "customerUnreadMessageCount";
        patch[unreadKey] = Number(booking[unreadKey] || 0) + 1;
      }
      tx.update(ref, {...patch, medication: next, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
      return {ok: true};
    });
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("failed-precondition", e.message || "用藥操作失敗");
  }
});
