const crypto = require("crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {toInt} = require("../daycare/daycare_utils");

/**
 * @param {*} value Raw value.
 * @return {string} Normalized string.
 */
function text(value) {
  return String(value || "").trim();
}

/**
 * @param {*} value Serializable value.
 * @return {string} SHA-256 digest.
 */
function hash(value) {
  return crypto.createHash("sha256")
      .update(JSON.stringify(value)).digest("hex");
}

/**
 * Optional for older clients. Only caller-controlled order inputs enter the
 * fingerprint: current prices, profile defaults and point balances may change
 * after a committed response is lost and must not prevent recovery.
 * @param {Object} params Authenticated scope and request payload.
 * @return {Object|null} Deterministic identity, or null for legacy requests.
 */
function storeOrderRequestIdentity({shopId, userId, requestData}) {
  const requestId = text(requestData.requestId);
  if (!requestId) return null;
  if (requestId.length > 160 || !shopId || !userId) {
    throw new HttpsError("invalid-argument", "商城訂單請求編號不正確。");
  }
  const items = Array.isArray(requestData.items) ? requestData.items : [];
  const normalizedItems = items.map((raw) => {
    if (!raw || typeof raw !== "object") {
      throw new HttpsError("invalid-argument", "商品資料不正確。");
    }
    const quantity = Number(raw.quantity);
    const bundlePromotionId = text(raw.bundlePromotionId);
    const productId = text(raw.productId);
    if (!Number.isInteger(quantity) || quantity <= 0 ||
        (!bundlePromotionId && !productId)) {
      throw new HttpsError("invalid-argument", "商品數量不正確。");
    }
    return bundlePromotionId ? {bundlePromotionId, quantity} :
      {productId, quantity};
  });
  const fingerprint = hash({
    version: 1,
    items: normalizedItems,
    fulfillmentType: text(requestData.fulfillmentType) || "pickup",
    customerName: text(requestData.customerName),
    customerPhone: text(requestData.customerPhone),
    requestedPoints: toInt(requestData.requestedPoints, 0),
  });
  return {
    shopId,
    userId,
    orderId: `req_${hash([shopId, userId, requestId])}`,
    fingerprint,
  };
}

/**
 * @param {Object} snapshot Firestore document snapshot.
 * @param {Object} identity Expected authenticated request scope.
 * @return {Object|null} Original creation response.
 */
function replayFromSnapshot(snapshot, identity) {
  if (!snapshot.exists) return null;
  const order = snapshot.data() || {};
  if (order.shopId !== identity.shopId || order.userId !== identity.userId ||
      order.creationRequestFingerprint !== identity.fingerprint) {
    throw new HttpsError(
        "already-exists",
        "此次結帳資料與前次不同，請先至我的訂單確認。",
    );
  }
  const response = order.creationResponse;
  if (!response || response.orderId !== snapshot.id ||
      response.shopId !== identity.shopId) {
    throw new HttpsError(
        "data-loss", "原訂單回傳資料不完整，請至我的訂單確認。",
    );
  }
  return {...response};
}

/**
 * Must run before fresh price, availability, profile or module checks.
 * @param {Object} orderRef Target order reference.
 * @param {Object|null} identity Optional idempotency identity.
 * @return {Promise<Object|null>} Original committed response or null.
 */
async function readStoreOrderReplay(orderRef, identity) {
  if (!identity) return null;
  return replayFromSnapshot(await orderRef.get(), identity);
}

/**
 * The repeated transaction read protects against simultaneous submissions.
 * All inventory/points/promotion writes in create are committed atomically with
 * the order and its immutable response; a retried callback skips them entirely.
 * @param {Object} params Firestore, identity and order-creation callback.
 * @return {Promise<Object>} Original or newly committed creation response.
 */
async function createStoreOrderOnce({firestore, orderRef, identity, create}) {
  return firestore.runTransaction(async (transaction) => {
    if (identity) {
      const replay = replayFromSnapshot(
          await transaction.get(orderRef), identity,
      );
      if (replay) return replay;
    }
    try {
      const {order, response} = await create(transaction);
      transaction.set(orderRef, {
        ...order,
        ...(identity ? {
          creationRequestVersion: 1,
          creationRequestFingerprint: identity.fingerprint,
          creationResponse: {...response},
        } : {}),
      });
      return response;
    } catch (error) {
      // A thrown callback cannot commit its queued writes. Only these failures
      // are safe to present as business errors that allow editing the request.
      if (error instanceof HttpsError) throw error;
      // Keep Firestore/gRPC errors intact so the SDK can retry the transaction.
      // A previous commit attempt may have succeeded without returning a reply.
      if (error && error.code != null) throw error;
      throw new HttpsError(
          "failed-precondition",
          error && error.message ? error.message : "無法建立商城訂單",
      );
    }
  });
}

/**
 * An error from runTransaction itself can mean the commit reply was lost.
 * Preserve explicit callback errors; keep unknown results retryable with the
 * same request instead of telling the client that no order was created.
 * @param {*} error Transaction failure.
 * @return {HttpsError} Callable error preserving the commit uncertainty.
 */
function storeOrderFailureFromTransaction(error) {
  if (error instanceof HttpsError) return error;
  return new HttpsError(
      "unavailable", "訂單結果尚未確認，請在同一頁重試，避免重新下單。",
  );
}

module.exports = {
  storeOrderRequestIdentity,
  readStoreOrderReplay,
  createStoreOrderOnce,
  storeOrderFailureFromTransaction,
};
