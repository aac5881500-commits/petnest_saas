/* eslint-disable require-jsdoc, max-len */
const {createHash} = require("node:crypto");
const {serviceTasks, canRecord} = require("./service_tasks");
const {reminderStage} = require("../medication/medication_reminders");
const enabled = (data) => !!data && data.enabled === true && Array.isArray(data.dailyTimedServices) && data.dailyTimedServices.length > 0;
const stageOf = (task, now) => task && task.petId && !task.record ? reminderStage({...task, result: "pending"}, now) : null;
async function sendServiceReminders(db, send, clock = Date.now) {
  const bookings = await db.collection("bookings").where("status", "==", "checked_in").get();
  const receivers = new Map();
  for (const doc of bookings.docs) {
    const b = doc.data(); if (!canRecord(b) || typeof b.shopId !== "string" || !b.shopId) continue;
    for (const task of serviceTasks(b)) {
      const stage = stageOf(task, clock()); if (!stage) continue;
      if (!receivers.has(b.shopId)) {
        const [shop, catalog, members] = await Promise.all([
          db.collection("shops").doc(b.shopId).get(),
          db.collection(`shops/${b.shopId}/addons`).doc("main").get(),
          db.collection("shop_members").where("shopId", "==", b.shopId).get(),
        ]);
        const ids = new Set();
        if (enabled(catalog.data()) && shop.exists) {
          ids.add(shop.data().ownerUid);
          for (const member of members.docs.map((d) => d.data())) {
            if (member.role === "owner" || (member.permissions || {}).manage_bookings === true) ids.add(member.uid);
          }
        }
        receivers.set(b.shopId, [...ids].filter((id) => typeof id === "string" && id));
      }
      for (const userId of receivers.get(b.shopId)) {
        const key = createHash("sha256").update(JSON.stringify([doc.id, task.id, task.scheduledAt, stage, userId])).digest("hex");
        const claim = doc.ref.collection("care_reminder_deliveries").doc(key);
        const acquired = await db.runTransaction(async (tx) => {
          const [delivery, booking, catalog] = await Promise.all([
            tx.get(claim), tx.get(doc.ref), tx.get(db.collection(`shops/${b.shopId}/addons`).doc("main")),
          ]);
          if (delivery.exists || !enabled(catalog.data()) || !canRecord(booking.data()) || booking.data().shopId !== b.shopId) return false;
          const current = serviceTasks(booking.data()).find((t) => t.id === task.id && t.scheduledAt === task.scheduledAt);
          if (stageOf(current, clock()) !== stage) return false;
          tx.create(claim, {stage, createdAt: new Date(clock())}); return true;
        });
        if (!acquired) continue;
        try {
          await send({notificationId: `staff_care_${key}`, userId,
            title: stage === "soon" ? "預約服務即將到點" : "預約服務已到點",
            body: "有一項照護服務待處理，請開啟 PetNest 查看並填寫結果。",
            data: {type: "staff_service_task", shopId: b.shopId, bookingId: doc.id, taskId: task.id, scheduledAt: task.scheduledAt}});
        } catch (error) {
          await claim.delete(); console.error("Care reminder delivery failed", error.code || "unknown");
        }
      }
    }
  }
}
module.exports = {sendServiceReminders, stageOf};
