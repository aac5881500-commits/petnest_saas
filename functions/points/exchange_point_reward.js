// functions/points/exchange_point_reward.js
// 🎁 中央庫存點數商品兌換
// 功能：Auth、Reward、點數、中央庫存在同一 Transaction 完成。
// 僅處理 useCentralInventory == true 的實體商品。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  preparePointRedemptionDeduct,
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
 * @param {string} redemptionId
 * @return {string}
 */
function buildPickupCode(redemptionId) {
  const normalizedId = String(redemptionId || "")
      .replace(/[^a-zA-Z0-9]/g, "")
      .toUpperCase();
  if (normalizedId.length >= 8) {
    return normalizedId.substring(normalizedId.length - 8);
  }
  return normalizedId.padStart(8, "0");
}

/**
 * @param {Object} shopMemberData
 * @param {Object} userProfileData
 * @param {Object} auth
 * @return {{name: string, phone: string}}
 */
function resolveMemberContact(shopMemberData, userProfileData, auth) {
  const globalTags = userProfileData.globalTags &&
    typeof userProfileData.globalTags === "object" &&
    !Array.isArray(userProfileData.globalTags) ?
    userProfileData.globalTags :
    {};
  const shopMemberName = normalizeString(shopMemberData.name);
  const profileName = normalizeString(
      globalTags.name || userProfileData.name,
  );
  const authName = auth && auth.token && auth.token.name ?
    normalizeString(auth.token.name) :
    "";
  const name = shopMemberName || profileName || authName;
  const shopMemberPhone = normalizeString(shopMemberData.phone);
  const profilePhone = normalizeString(
      globalTags.phone || userProfileData.phone,
  );
  const phone = shopMemberPhone || profilePhone;
  return {name, phone};
}

exports.exchangePointReward = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入會員帳號");
      }

      const requestData = request.data || {};
      const shopId = normalizeString(requestData.shopId);
      const rewardId = normalizeString(requestData.rewardId);
      const requestId = normalizeString(requestData.requestId);
      const userId = request.auth.uid;

      if (!shopId) {
        throw new HttpsError("invalid-argument", "缺少店家 ID");
      }
      if (!rewardId) {
        throw new HttpsError("invalid-argument", "缺少點數兌換商品 ID");
      }
      if (!requestId) {
        throw new HttpsError("invalid-argument", "缺少兌換請求編號");
      }

      const firestore = admin.firestore();

      try {
        const result = await firestore.runTransaction(async (transaction) => {
          const pointSettingRef = firestore
              .collection("shops").doc(shopId)
              .collection("settings").doc("points");
          const rewardRef = firestore
              .collection("shops").doc(shopId)
              .collection("point_rewards").doc(rewardId);
          const memberPointRef = firestore
              .collection("shops").doc(shopId)
              .collection("member_points").doc(userId);
          const shopMemberRef = firestore
              .collection("shops").doc(shopId)
              .collection("members").doc(userId);
          const userProfileRef = firestore
              .collection("user_profiles").doc(userId);
          const memberExchangeRef = rewardRef
              .collection("member_exchanges").doc(userId);
          const redemptionRef = firestore
              .collection("shops").doc(shopId)
              .collection("point_redemptions").doc(requestId);
          const pointLogRef = firestore
              .collection("shops").doc(shopId)
              .collection("member_point_logs").doc();

          const pointSettingSnapshot = await transaction.get(pointSettingRef);
          const rewardSnapshot = await transaction.get(rewardRef);
          const memberPointSnapshot = await transaction.get(memberPointRef);
          const shopMemberSnapshot = await transaction.get(shopMemberRef);
          const userProfileSnapshot = await transaction.get(userProfileRef);
          const memberExchangeSnapshot = await transaction.get(
              memberExchangeRef,
          );
          const redemptionSnapshot = await transaction.get(redemptionRef);

          if (redemptionSnapshot.exists) {
            const existing = redemptionSnapshot.data() || {};
            if (normalizeString(existing.userId) !== userId ||
              normalizeString(existing.rewardId) !== rewardId) {
              throw new Error("此兌換請求已被使用");
            }
            return {
              redemptionId: requestId,
              alreadyCompleted: true,
            };
          }

          const pointSettingData = pointSettingSnapshot.exists ?
            (pointSettingSnapshot.data() || {}) :
            null;
          if (!pointSettingData) {
            throw new Error("店家尚未設定點數制度");
          }
          if (pointSettingData.enabled !== true) {
            throw new Error("店家目前未啟用點數制度");
          }
          if (pointSettingData.allowPointsExchange !== true) {
            throw new Error("店家目前未開放點數兌換");
          }

          if (!rewardSnapshot.exists) {
            throw new Error("找不到此點數兌換商品");
          }
          const reward = rewardSnapshot.data() || {};
          if (reward.enabled === false) {
            throw new Error("此兌換商品目前未開放");
          }
          const pointsCost = toInt(reward.pointsCost);
          if (pointsCost <= 0) {
            throw new Error("此兌換商品點數設定錯誤");
          }
          if (normalizeString(reward.fulfillmentType) !== "physicalProduct") {
            throw new Error("此兌換商品不是實體商品");
          }
          const inventoryItemId = normalizeString(reward.inventoryItemId);
          if (reward.useCentralInventory !== true || !inventoryItemId) {
            throw new Error("此商品未使用中央庫存，請使用原本兌換流程");
          }

          const exchangedCount = toInt(reward.exchangedCount);
          const totalExchangeLimit = toInt(reward.totalExchangeLimit);
          if (totalExchangeLimit > 0 && exchangedCount >= totalExchangeLimit) {
            throw new Error("此兌換商品已兌換完畢");
          }

          const memberExchangedCount = toInt(
              (memberExchangeSnapshot.data() || {}).exchangedCount,
          );
          const exchangeLimitPerMember = toInt(reward.exchangeLimitPerMember);
          if (exchangeLimitPerMember > 0 &&
            memberExchangedCount >= exchangeLimitPerMember) {
            throw new Error("你已達到此商品的兌換次數上限");
          }

          const memberPoint = memberPointSnapshot.exists ?
            (memberPointSnapshot.data() || {}) :
            {};
          const balanceBefore = toInt(memberPoint.currentPoints);
          const balanceAfter = balanceBefore - pointsCost;
          if (balanceAfter < 0) {
            throw new Error(
                `點數不足，目前有 ${balanceBefore} 點，需要 ${pointsCost} 點`,
            );
          }

          let inventoryQuantity = Number(
              reward.inventoryQuantityPerExchange || 1,
          );
          if (!Number.isFinite(inventoryQuantity) || inventoryQuantity <= 0) {
            inventoryQuantity = 1;
          }

          const inventoryPlan = await preparePointRedemptionDeduct(
              transaction,
              {
                shopId,
                redemptionId: requestId,
                inventoryItemId,
                quantity: inventoryQuantity,
                itemName: normalizeString(reward.name),
                note: "點數兌換立即扣庫存",
              },
          );

          const contact = resolveMemberContact(
              shopMemberSnapshot.exists ?
                (shopMemberSnapshot.data() || {}) :
                {},
              userProfileSnapshot.exists ?
                (userProfileSnapshot.data() || {}) :
                {},
              request.auth,
          );

          const now = admin.firestore.FieldValue.serverTimestamp();
          const validDays = toInt(reward.validDays);
          const expireAt = validDays > 0 ?
            admin.firestore.Timestamp.fromMillis(
                Date.now() + validDays * 24 * 60 * 60 * 1000,
            ) :
            null;
          const rewardName = normalizeString(reward.name);
          const inventoryItemName = normalizeString(reward.inventoryItemName) ||
            rewardName;

          const memberPointWrite = {
            shopId,
            userId,
            currentPoints: balanceAfter,
            totalUsedPoints: toInt(memberPoint.totalUsedPoints) + pointsCost,
            lastUsedAt: now,
            updatedAt: now,
          };
          if (!memberPointSnapshot.exists) {
            memberPointWrite.totalEarnedPoints = 0;
            memberPointWrite.totalExpiredPoints = 0;
            memberPointWrite.createdAt = now;
          }

          transaction.set(memberPointRef, memberPointWrite, {merge: true});

          transaction.set(pointLogRef, {
            shopId,
            userId,
            type: "rewardExchange",
            points: -pointsCost,
            balanceBefore,
            balanceAfter,
            reason: `兌換「${rewardName}」`,
            operatorUid: userId,
            sourceId: rewardId,
            bookingId: "",
            rewardId,
            couponId: "",
            redemptionId: requestId,
            note: "",
            createdAt: now,
          });

          transaction.set(redemptionRef, {
            shopId,
            userId,
            rewardId,
            rewardName,
            rewardDescription: normalizeString(reward.description),
            rewardImageUrl: normalizeString(reward.imageUrl),
            fulfillmentNote: normalizeString(reward.fulfillmentNote),
            pointsCost,
            balanceBefore,
            balanceAfter,
            status: "pendingPickup",
            pickupCode: buildPickupCode(requestId),
            expireAt,
            pickedUpBy: "",
            cancelledBy: "",
            cancelReason: "",
            pointsRefunded: false,
            pointsRefundedBy: "",
            useCentralInventory: true,
            inventoryItemId,
            inventoryItemName,
            inventoryUnit: normalizeString(reward.inventoryUnit),
            inventoryQuantity,
            inventoryDeducted: true,
            inventoryReturned: false,
            memberName: contact.name,
            memberPhone: contact.phone,
            note: "",
            createdAt: now,
            updatedAt: now,
          });

          transaction.update(rewardRef, {
            exchangedCount: exchangedCount + 1,
            updatedAt: now,
          });

          const memberExchangeData = memberExchangeSnapshot.data() || {};
          const memberExchangeHasCreatedAt =
            memberExchangeSnapshot.exists &&
            memberExchangeData.createdAt;
          const memberExchangeWrite = {
            shopId,
            rewardId,
            userId,
            exchangedCount: memberExchangedCount + 1,
            lastCouponId: "",
            lastRedemptionId: requestId,
            lastExchangedAt: now,
            updatedAt: now,
          };
          if (!memberExchangeHasCreatedAt) {
            memberExchangeWrite.createdAt = now;
          }
          transaction.set(
              memberExchangeRef,
              memberExchangeWrite,
              {merge: true},
          );

          commitPreparedConsumption(transaction, inventoryPlan, userId);

          return {
            redemptionId: requestId,
            alreadyCompleted: false,
          };
        });

        return result;
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError(
            "failed-precondition",
            error && error.message ? error.message : "無法完成點數兌換",
        );
      }
    },
);
