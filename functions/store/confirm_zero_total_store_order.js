const {HttpsError} = require("firebase-functions/v2/https");
const {convertReservationToDeduct} = require("./store_inventory");

/**
 * Confirm an already-created zero-cash order using the normal stock finalizer.
 * The caller reads orderRef in the same transaction and writes the returned
 * patch. No new point deduction, gateway transaction, or price calculation.
 * @param {Object} params Transaction, stored order and actor context.
 * @return {Promise<Object|null>} Null means already confirmed; otherwise patch.
 */
async function confirmZeroTotalStoreOrder({
  firestore,
  transaction,
  shopId,
  orderId,
  actorUid,
  canManage,
  order,
  now,
  nowMs = Date.now(),
  convertInventory = convertReservationToDeduct,
}) {
  const ownerUid = String(order.userId || "").trim();
  if (!actorUid || !ownerUid || (actorUid !== ownerUid && !canManage)) {
    throw new HttpsError("permission-denied", "沒有權限確認此商城訂單。");
  }
  if (String(order.shopId || "") !== shopId) {
    throw new HttpsError("failed-precondition", "商城訂單店家不一致。");
  }
  if (typeof order.totalAmount !== "number" || order.totalAmount !== 0) {
    throw new HttpsError("failed-precondition", "此訂單仍需付款，請選擇付款方式。");
  }
  const completed = ["paid", "preparing", "ready_for_pickup", "completed"];
  if (completed.includes(order.status) && order.paymentStatus === "paid") {
    return null;
  }
  if (order.status !== "pending_payment" || order.paymentStatus !== "unpaid" ||
      order.inventoryReturned === true) {
    throw new HttpsError("failed-precondition", "此訂單目前無法確認。");
  }

  const shopRef = firestore.collection("shops").doc(shopId);
  const reservationSnap = await transaction.get(
      shopRef.collection("store_reservations").doc(orderId),
  );
  const reservation = reservationSnap.exists ? reservationSnap.data() : null;
  const expires = reservation && reservation.expireAt;
  const expiresMs = expires && typeof expires.toMillis === "function" ?
    expires.toMillis() : NaN;
  if (!reservation || reservation.status !== "held" ||
      !Number.isFinite(expiresMs) || expiresMs <= nowMs) {
    throw new HttpsError("deadline-exceeded", "庫存保留已過期，請重新下單。");
  }
  if (String(reservation.userId || "") !== ownerUid ||
      !Array.isArray(reservation.lines) || reservation.lines.length === 0) {
    throw new HttpsError("failed-precondition", "訂單庫存保留資料不完整。");
  }

  const pointsUsed = order.pointsUsed == null ? 0 : order.pointsUsed;
  const pointAmount = order.pointAmount == null ? 0 : order.pointAmount;
  if (!Number.isInteger(pointsUsed) || pointsUsed < 0 ||
      !Number.isInteger(pointAmount) || pointAmount < 0) {
    throw new HttpsError("failed-precondition", "訂單點數折抵資料不正確。");
  }
  if (pointsUsed > 0 || pointAmount > 0) {
    const spendSnap = await transaction.get(
        shopRef.collection("member_point_logs").doc(`spend_store_${orderId}`),
    );
    const spend = spendSnap.exists ? spendSnap.data() : null;
    if (!spend || spend.returned === true || pointsUsed <= 0 ||
        pointAmount <= 0 || spend.points !== -pointsUsed ||
        spend.amount !== pointAmount || spend.userId !== ownerUid ||
        spend.shopId !== shopId) {
      throw new HttpsError("failed-precondition", "尚無有效的訂單扣點紀錄。");
    }
  }

  await convertInventory({transaction, shopId, orderId, userId: actorUid});
  return {
    status: "paid",
    paymentStatus: "paid",
    paidAt: now,
    lastPaymentAmount: 0,
    lastPaymentMethod: pointsUsed > 0 ? "points" : "no_payment_required",
  };
}

module.exports = {confirmZeroTotalStoreOrder};
