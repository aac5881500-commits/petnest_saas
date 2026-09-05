// 檔案名稱：functions/points/cancel_point_redemption.js
// 功能說明：驗證資格、可選退點、idempotent 返還庫存，同一 Transaction。
// 🎁 取消中央庫存點數實體商品兌換

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  preparePointRedemptionReturn,
  commitPreparedConsumption,
} = require("../inventory/inventory_consumption");

/**
 * @param {string} value
 * @return {string}
 */
function normalizeString(value) {
  return String(value || "").trim();
}

/**
 * @param {*} value
 * @return {number}
 */
function toInt(value) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) {
    return 0;
  }
  return Math.trunc(numberValue);
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
 * @return {boolean}
 */
function canManagePointRedemptions(member) {
  if (!member) {
    return false;
  }
  if (member.role === "owner") {
    return true;
  }
  if (member.permissions &&
    member.permissions.manage_point_redemptions === true) {
    return true;
  }
  const hasMap = member.permissions && typeof member.permissions === "object";
  const hasKey = hasMap &&
    Object.prototype.hasOwnProperty.call(
        member.permissions,
        "manage_point_redemptions",
    );
  if (!hasKey && (member.role === "manager" || member.role === "staff")) {
    return true;
  }
  return false;
}

exports.cancelPointRedemption = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入店員帳號");
      }

      const requestData = request.data || {};
      const shopId = normalizeString(requestData.shopId);
      const redemptionId = normalizeString(requestData.redemptionId);
      const reason = normalizeString(requestData.reason);
      const refundPoints = requestData.refundPoints === true;
      const uid = request.auth.uid;

      if (!shopId || !redemptionId) {
        throw new HttpsError("invalid-argument", "缺少兌換紀錄資料");
      }
      if (!reason) {
        throw new HttpsError("invalid-argument", "請填寫取消原因");
      }

      const member = await getShopMember(shopId, uid);
      if (!canManagePointRedemptions(member)) {
        throw new HttpsError("permission-denied", "沒有權限取消兌換");
      }

      const firestore = admin.firestore();

      try {
        await firestore.runTransaction(async (transaction) => {
          const redemptionRef = firestore
              .collection("shops").doc(shopId)
              .collection("point_redemptions").doc(redemptionId);

          const redemptionSnapshot = await transaction.get(redemptionRef);
          if (!redemptionSnapshot.exists) {
            throw new Error("找不到此實體商品兌換紀錄");
          }
          const redemption = redemptionSnapshot.data() || {};
          const status = normalizeString(redemption.status);

          if (status === "pickedUp") {
            throw new Error("商品已完成領取，無法取消");
          }
          if (status === "cancelled") {
            throw new Error("此兌換紀錄已經取消");
          }
          if (status === "expired") {
            throw new Error("此兌換紀錄已過期，無法直接取消");
          }
          if (status !== "pendingPickup") {
            throw new Error("只有待領取商品可以取消");
          }
          if (refundPoints && redemption.pointsRefunded === true) {
            throw new Error("此兌換紀錄已經退回點數");
          }

          const memberUserId = normalizeString(redemption.userId);
          const rewardId = normalizeString(redemption.rewardId);
          if (!memberUserId) {
            throw new Error("兌換紀錄缺少會員 UID");
          }
          if (!rewardId) {
            throw new Error("兌換紀錄缺少商品 ID");
          }

          const rewardRef = firestore
              .collection("shops").doc(shopId)
              .collection("point_rewards").doc(rewardId);
          const memberExchangeRef = rewardRef
              .collection("member_exchanges").doc(memberUserId);
          const memberPointRef = firestore
              .collection("shops").doc(shopId)
              .collection("member_points").doc(memberUserId);
          const pointLogRef = firestore
              .collection("shops").doc(shopId)
              .collection("member_point_logs").doc();

          const rewardSnapshot = await transaction.get(rewardRef);
          const memberExchangeSnapshot = await transaction.get(
              memberExchangeRef,
          );

          let memberPointSnapshot = null;
          if (refundPoints) {
            memberPointSnapshot = await transaction.get(memberPointRef);
          }

          const useCentralInventory = redemption.useCentralInventory === true &&
            normalizeString(redemption.inventoryItemId) !== "" &&
            redemption.inventoryReturned !== true;

          let inventoryReturnPlan = {skip: true, lines: []};
          if (useCentralInventory) {
            inventoryReturnPlan = await preparePointRedemptionReturn(
                transaction,
                {shopId, redemptionId},
            );
          }

          const rewardData = rewardSnapshot.exists ?
            (rewardSnapshot.data() || {}) :
            {};
          const exchangedCount = toInt(rewardData.exchangedCount);
          const memberExchangedCount = toInt(
              (memberExchangeSnapshot.data() || {}).exchangedCount,
          );
          const now = admin.firestore.FieldValue.serverTimestamp();
          const inventoryReturned = inventoryReturnPlan.skip ?
            redemption.inventoryReturned === true :
            true;

          const redemptionUpdate = {
            status: "cancelled",
            cancelledAt: now,
            cancelledBy: uid,
            cancelReason: reason,
            pointsRefunded: refundPoints,
            inventoryReturned,
            updatedAt: now,
          };
          if (refundPoints) {
            redemptionUpdate.pointsRefundedAt = now;
            redemptionUpdate.pointsRefundedBy = uid;
          }

          transaction.update(redemptionRef, redemptionUpdate);

          if (rewardSnapshot.exists) {
            transaction.update(rewardRef, {
              exchangedCount: exchangedCount > 0 ? exchangedCount - 1 : 0,
              updatedAt: now,
            });
          }

          if (memberExchangeSnapshot.exists) {
            transaction.set(memberExchangeRef, {
              exchangedCount: memberExchangedCount > 0 ?
                memberExchangedCount - 1 :
                0,
              updatedAt: now,
            }, {merge: true});
          }

          if (refundPoints) {
            const memberPoint = memberPointSnapshot &&
              memberPointSnapshot.exists ?
              (memberPointSnapshot.data() || {}) :
              {};
            const pointsCost = toInt(redemption.pointsCost);
            const balanceBefore = toInt(memberPoint.currentPoints);
            const balanceAfter = balanceBefore + pointsCost;
            const nextTotalUsed = toInt(memberPoint.totalUsedPoints) -
              pointsCost;

            transaction.set(memberPointRef, {
              shopId,
              userId: memberUserId,
              currentPoints: balanceAfter,
              totalUsedPoints: nextTotalUsed < 0 ? 0 : nextTotalUsed,
              updatedAt: now,
            }, {merge: true});

            transaction.set(pointLogRef, {
              shopId,
              userId: memberUserId,
              type: "refunded",
              points: pointsCost,
              balanceBefore,
              balanceAfter,
              reason: `取消兌換「${normalizeString(redemption.rewardName)}」退回點數`,
              operatorUid: uid,
              sourceId: redemptionId,
              bookingId: "",
              rewardId,
              couponId: "",
              redemptionId,
              note: reason,
              createdAt: now,
            });
          }

          commitPreparedConsumption(transaction, inventoryReturnPlan, uid);
        });

        return {ok: true};
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError(
            "failed-precondition",
            error && error.message ? error.message : "無法取消兌換",
        );
      }
    },
);
