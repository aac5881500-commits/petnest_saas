// 檔案名稱：functions/store/update_store_order_status.js
// 功能說明：合法狀態流轉；未付款取消釋放 reservation；已扣庫存取消才 idempotent 返還。
// 🛒 商城訂單狀態變更

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

const {
  releaseReservation,
  returnStoreOrderStock,
  expireRelatedHeldReservations,
} = require("./store_inventory");
const {
  applyReportContribution,
} = require("../reports/shop_report_summary");

/**
 * @param {string} value
 * @return {string}
 */
function normalizeString(value) {
  return String(value || "").trim();
}

/**
 * @param {string} shopId
 * @param {string} uid
 * @return {Promise<Object|null>}
 */
async function getShopMember(shopId, uid) {
  const snapshot = await admin.firestore()
      .collection("shop_members")
      .doc(`${shopId}_${uid}`)
      .get();
  if (!snapshot.exists) {
    return null;
  }
  return snapshot.data() || {};
}

/**
 * @param {Object|null} member
 * @param {string} key
 * @return {boolean}
 */
function hasPermission(member, key) {
  if (!member) {
    return false;
  }
  if (member.role === "owner") {
    return true;
  }
  return member.permissions && member.permissions[key] === true;
}

exports.updateStoreOrderStatus = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入。");
      }

      const shopId = normalizeString(request.data && request.data.shopId);
      const orderId = normalizeString(request.data && request.data.orderId);
      const action = normalizeString(request.data && request.data.action);
      const reason = normalizeString(request.data && request.data.reason);
      const uid = request.auth.uid;

      if (!shopId || !orderId || !action) {
        throw new HttpsError("invalid-argument", "缺少訂單操作資料。");
      }

      const firestore = admin.firestore();
      const orderRef = firestore
          .collection("shops")
          .doc(shopId)
          .collection("store_orders")
          .doc(orderId);
      const member = await getShopMember(shopId, uid);
      let completedOrder = null;

      await firestore.runTransaction(async (transaction) => {
        const orderSnapshot = await transaction.get(orderRef);
        if (!orderSnapshot.exists) {
          throw new HttpsError("not-found", "找不到商城訂單。");
        }

        const order = orderSnapshot.data() || {};
        const status = normalizeString(order.status);
        const isOwner = normalizeString(order.userId) === uid;
        const canManage = hasPermission(member, "manage_store_orders");
        const canView = canManage ||
          hasPermission(member, "view_store_orders");
        const now = admin.firestore.FieldValue.serverTimestamp();
        const update = {
          updatedAt: now,
          updatedBy: uid,
        };

        if (action === "cancel") {
          if (!isOwner && !canManage) {
            throw new HttpsError("permission-denied", "沒有權限取消訂單。");
          }

          if (status === "cancelled" || status === "completed") {
            throw new HttpsError("failed-precondition", "此訂單無法取消。");
          }

          if (status === "pending_payment") {
            await releaseReservation({
              transaction,
              shopId,
              orderId,
              userId: uid,
            });
          } else if (
            ["paid", "preparing", "ready_for_pickup"].includes(status)
          ) {
            if (!canManage) {
              throw new HttpsError(
                  "permission-denied",
                  "已付款訂單請由店家處理取消。",
              );
            }
            await returnStoreOrderStock({
              transaction,
              shopId,
              orderId,
              userId: uid,
            });
            update.inventoryReturned = true;
          } else {
            throw new HttpsError("failed-precondition", "此狀態不可取消。");
          }

          update.status = "cancelled";
          update.cancelledAt = now;
          update.cancelReason = reason || "取消訂單";
        } else if (action === "start_preparing") {
          if (!canManage) {
            throw new HttpsError("permission-denied", "沒有權限管理商城訂單。");
          }
          if (status !== "paid") {
            throw new HttpsError("failed-precondition", "僅已付款訂單可開始備貨。");
          }
          update.status = "preparing";
          update.preparingAt = now;
        } else if (action === "mark_ready") {
          if (!canManage) {
            throw new HttpsError("permission-denied", "沒有權限管理商城訂單。");
          }
          if (status !== "preparing") {
            throw new HttpsError("failed-precondition", "請先開始備貨。");
          }
          update.status = "ready_for_pickup";
          update.readyForPickupAt = now;
        } else if (action === "complete") {
          if (!canManage) {
            throw new HttpsError("permission-denied", "沒有權限管理商城訂單。");
          }
          if (status !== "ready_for_pickup") {
            throw new HttpsError("failed-precondition", "僅可取貨訂單可完成取貨。");
          }
          update.status = "completed";
          update.completedAt = now;
          completedOrder = order;
        } else if (action === "touch") {
          if (!isOwner && !canView) {
            throw new HttpsError("permission-denied", "沒有權限。");
          }
          if (status !== "pending_payment") {
            return;
          }
          const itemIds = Array.isArray(order.items) ?
            order.items.map((item) => String(item.inventoryItemId || "")) :
            [];
          await expireRelatedHeldReservations(transaction, {
            shopId,
            itemIds,
            extraReservationIds: [orderId],
            userId: uid,
          });
        } else if (action === "release_expired") {
          if (!isOwner && !canView) {
            throw new HttpsError("permission-denied", "沒有權限。");
          }
          if (status !== "pending_payment") {
            return;
          }
          const itemIds = Array.isArray(order.items) ?
            order.items.map((item) => String(item.inventoryItemId || "")) :
            [];
          await expireRelatedHeldReservations(transaction, {
            shopId,
            itemIds,
            extraReservationIds: [orderId],
            userId: uid,
          });
        } else {
          throw new HttpsError("invalid-argument", "不支援的訂單操作。");
        }

        transaction.set(orderRef, update, {merge: true});
      });

      if (completedOrder) {
        try {
          await applyReportContribution(admin.firestore(), {
            shopId,
            sourceId: `store_${orderId}`,
            next: {
              stayOrderCount: 0,
              daycareOrderCount: 0,
              storeOrderCount: 1,
              stayRevenue: 0,
              daycareRevenue: 0,
              storeRevenue: Number(completedOrder.totalAmount || 0),
              refundAmount: 0,
              discountAmount: 0,
              addonRevenue: 0,
              newMemberCount: 0,
              cancelledOrderCount: 0,
              completedCount: 0,
              confirmedCount: 0,
            },
          });
        } catch (reportError) {
          console.error("商城營運摘要更新失敗", reportError);
        }
      }

      return {ok: true};
    },
);
