/* eslint-disable require-jsdoc */
const {createHash} = require("node:crypto");

const MINUTE = 60 * 1000;
const ADVANCE_MS = 15 * MINUTE;
const CATCH_UP_MS = 60 * MINUTE;

function activeMedication(booking) {
  return booking && booking.status === "checked_in" &&
    booking.settlementConfirmed !== true && booking.settlementLocked !== true &&
    !booking.settledAt && booking.medication &&
    booking.medication.state === "confirmed" &&
    booking.medication.finalized !== true;
}

function reminderStage(task, now) {
  if (!task || task.finished === true ||
    !["pending", "partial", "mixed"].includes(task.result)) return null;
  const remaining = Date.parse(task.scheduledAt) - now;
  if (!Number.isFinite(remaining)) return null;
  if (remaining <= 0) return remaining >= -CATCH_UP_MS ? "due" : null;
  return remaining <= ADVANCE_MS ? "soon" : null;
}

function medicationEnabled(shop) {
  return Boolean(shop && shop.medicationSetting &&
    shop.medicationSetting.enabled === true);
}

async function recipients(db, shopId) {
  const [shop, members] = await Promise.all([
    db.collection("shops").doc(shopId).get(),
    db.collection("shop_members").where("shopId", "==", shopId).get(),
  ]);
  if (!shop.exists || !medicationEnabled(shop.data())) return [];
  const ids = new Set([(shop.data() || {}).ownerUid]);
  for (const doc of members.docs) {
    const member = doc.data();
    if (member.role === "owner" ||
        (member.permissions || {}).manage_bookings === true) {
      ids.add(member.uid);
    }
  }
  return [...ids].filter((uid) => typeof uid === "string" && uid.length > 0);
}

async function sendMedicationReminders(db, send, clock = Date.now) {
  const bookings = await db.collection("bookings")
      .where("status", "==", "checked_in").get();
  const byShop = new Map();
  for (const doc of bookings.docs) {
    const booking = doc.data();
    if (!activeMedication(booking) ||
        typeof booking.shopId !== "string" || !booking.shopId) continue;
    const tasks = Array.isArray(booking.medication.tasks) ?
      booking.medication.tasks : [];
    for (const task of tasks) {
      const stage = reminderStage(task, clock());
      if (!stage || typeof task.id !== "string" || !task.id) continue;
      if (!byShop.has(booking.shopId)) {
        byShop.set(booking.shopId, await recipients(db, booking.shopId));
      }
      for (const userId of byShop.get(booking.shopId)) {
        const key = createHash("sha256")
            .update(JSON.stringify([
              doc.id, task.id, task.scheduledAt, stage, userId,
            ]))
            .digest("hex");
        const claim = doc.ref
            .collection("medication_reminder_deliveries").doc(key);
        const claimed = await db.runTransaction(async (tx) => {
          const delivery = await tx.get(claim);
          if (delivery.exists) return false;
          const shopRef = db.collection("shops").doc(booking.shopId);
          const [fresh, settings] = await Promise.all([
            tx.get(doc.ref), tx.get(shopRef),
          ]);
          if (!medicationEnabled(settings.data())) return false;
          const current = fresh.data();
          if (!activeMedication(current) ||
              current.shopId !== booking.shopId ||
              !Array.isArray(current.medication.tasks)) return false;
          const currentTask = current.medication.tasks.find(
              (item) => item && item.id === task.id &&
                item.scheduledAt === task.scheduledAt,
          );
          if (reminderStage(currentTask, clock()) !== stage) return false;
          tx.create(claim, {createdAt: new Date(clock()), stage});
          return true;
        });
        if (!claimed) continue;
        const time = new Intl.DateTimeFormat("en-GB", {
          timeZone: "Asia/Taipei",
          hour: "2-digit", minute: "2-digit", hourCycle: "h23",
        }).format(new Date(task.scheduledAt));
        try {
          await send({
            notificationId: `staff_medication_${key}`,
            userId,
            title: stage === "soon" ? "用藥即將到點" : "用藥已到點",
            body: `${time} 的照護待辦，請開啟 PetNest 查看。`,
            data: {
              type: "staff_medication_task", shopId: booking.shopId,
              bookingId: doc.id, taskId: task.id, scheduledAt: task.scheduledAt,
            },
          });
        } catch (error) {
          await claim.delete();
          console.error("Medication reminder delivery failed",
              error.code || "unknown");
        }
      }
    }
  }
}

module.exports = {activeMedication, reminderStage, sendMedicationReminders};
