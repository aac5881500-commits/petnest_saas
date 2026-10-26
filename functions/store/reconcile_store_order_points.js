// 商城任何取消來源（含庫存過期清理）都透過事件補償退點。
// 使用既有 spend_store_* 紀錄的 returned 防重複；瞬時錯誤交由事件重試。
const admin = require("firebase-admin");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {
  restoreSpend,
  spendStoreLogId,
} = require("../points/sync_booking_points");
const {normalizeString, toInt} = require("../daycare/daycare_utils");

/**
 * @param {Object} params Event snapshot and Firestore dependency.
 * @return {Promise<boolean>} Whether a cancelled order needed reconciliation.
 */
async function reconcileCancelledStoreOrderPoints({
  firestore,
  shopId,
  orderId,
  order,
  previousOrder,
}) {
  if (!order || normalizeString(order.status) !== "cancelled" ||
      normalizeString(previousOrder && previousOrder.status) === "cancelled" ||
      order.pointsReturned === true) {
    return false;
  }
  const userId = normalizeString(order.userId);
  if (!userId || (toInt(order.pointsUsed, 0) <= 0 &&
      toInt(order.pointAmount, 0) <= 0)) {
    return false;
  }
  const orderRef = firestore.collection("shops").doc(shopId)
      .collection("store_orders").doc(orderId);
  const spendRef = firestore.collection("shops").doc(shopId)
      .collection("member_point_logs").doc(spendStoreLogId(orderId));
  const spendSnapshot = await spendRef.get();
  if (!spendSnapshot.exists) {
    // The order claims points were spent. A delayed/missing log must not make
    // this event succeed silently; the retry resumes once the log is available.
    throw new Error("Cancelled store order is missing its points spend log");
  }
  await restoreSpend(firestore, {
    shopId,
    bookingId: orderId,
    booking: {userId, pointAmount: toInt(order.pointAmount, 0)},
    extraRef: orderRef,
    spendLogId: spendStoreLogId(orderId),
  });
  return true;
}

exports.reconcileCancelledStoreOrderPoints = reconcileCancelledStoreOrderPoints;
exports.reconcileStoreOrderPoints = onDocumentUpdated(
    {
      document: "shops/{shopId}/store_orders/{orderId}",
      region: "asia-east1",
      retry: true,
    },
    async (event) => {
      const order = event.data && event.data.after && event.data.after.data();
      const previousOrder = event.data && event.data.before &&
        event.data.before.data();
      await reconcileCancelledStoreOrderPoints({
        firestore: admin.firestore(),
        shopId: event.params.shopId,
        orderId: event.params.orderId,
        order,
        previousOrder,
      });
    },
);
