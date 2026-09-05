// 檔案名稱：functions/bookings/finalize_booking_addon_inventory.js
// 功能說明：Customer / 店家建立 booking 後，依店家加購設定驗證並扣除中央庫存。
// 🏨 住宿加購庫存後端扣除
// 不信任 Client 傳入的品名、現有庫存、最終扣除量。
// 同一 booking 使用 ba_{bookingId}_deduct，重複呼叫安全 skip。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  roundQuantity,
} = require("../inventory/inventory_cost");
const {
  bookingAddonDeductId,
  prepareMergedDeduct,
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
 * @param {string} shopId
 * @param {string} uid
 * @return {Promise<boolean>}
 */
async function isShopMember(shopId, uid) {
  const snapshot = await admin.firestore()
      .collection("shop_members")
      .doc(`${shopId}_${uid}`)
      .get();
  return snapshot.exists;
}

/**
 * @param {Object} addon
 * @return {number}
 */
function addonPurchaseCount(addon) {
  const raw = addon && addon.count;
  let count = 1;
  if (typeof raw === "number" && Number.isFinite(raw)) {
    count = raw;
  } else {
    const parsed = Number(raw);
    if (Number.isFinite(parsed)) {
      count = parsed;
    }
  }
  return count <= 0 ? 1 : count;
}

/**
 * @param {*} value
 * @return {Array<Object>}
 */
function parseCatalogBindings(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  const result = [];
  value.forEach((raw) => {
    if (!raw || typeof raw !== "object") {
      return;
    }
    const inventoryItemId = normalizeString(raw.inventoryItemId);
    const quantityPerUnit = Number(raw.quantityPerUnit);
    if (!inventoryItemId) {
      return;
    }
    if (!Number.isFinite(quantityPerUnit) || quantityPerUnit <= 0) {
      return;
    }
    result.push({
      inventoryItemId,
      quantityPerUnit,
    });
  });
  return result;
}

/**
 * @param {Object} addonData
 * @param {string} type
 * @return {Array<Object>}
 */
function catalogListForType(addonData, type) {
  if (type === "value") {
    return Array.isArray(addonData.valueServices) ?
      addonData.valueServices : [];
  }
  if (type === "custom") {
    return Array.isArray(addonData.customServices) ?
      addonData.customServices : [];
  }
  if (type === "daily_timed") {
    return Array.isArray(addonData.dailyTimedServices) ?
      addonData.dailyTimedServices : [];
  }
  return [];
}

/**
 * 以店家加購主檔對應 booking 加購項目。
 *
 * @param {Object} addonData
 * @param {Object} bookingAddon
 * @return {Object|null}
 */
function findCatalogService(addonData, bookingAddon) {
  const type = normalizeString(bookingAddon.type);
  const list = catalogListForType(addonData, type);
  const addonId = normalizeString(
      bookingAddon.id || bookingAddon.serviceId,
  );
  const addonName = normalizeString(bookingAddon.name);

  if (addonId) {
    const byId = list.find((service) => {
      return normalizeString(service && service.id) === addonId;
    });
    if (byId) {
      return byId;
    }
  }

  if (addonName) {
    const byName = list.find((service) => {
      const name = normalizeString(
          (service && (service.name || service.label)) || "",
      );
      return name === addonName;
    });
    if (byName) {
      return byName;
    }
  }
  return null;
}

/**
 * 依店家加購設定產生扣除行，並合併相同 inventoryItemId。
 *
 * @param {Object} booking
 * @param {Object} addonData
 * @return {Array<Object>}
 */
function buildAddonDeductLines(booking, addonData) {
  const rawAddons = Array.isArray(booking.addons) ? booking.addons : [];
  const lines = [];

  rawAddons.forEach((rawAddon) => {
    if (!rawAddon || typeof rawAddon !== "object") {
      return;
    }
    const catalog = findCatalogService(addonData, rawAddon);
    if (!catalog || catalog.useInventory !== true) {
      return;
    }
    const bindings = parseCatalogBindings(catalog.inventoryBindings);
    if (bindings.length === 0) {
      return;
    }
    const count = addonPurchaseCount(rawAddon);
    const addonName = normalizeString(rawAddon.name || catalog.name);
    bindings.forEach((binding) => {
      const quantity = roundQuantity(
          binding.quantityPerUnit * count,
      );
      if (quantity <= 0) {
        return;
      }
      lines.push({
        inventoryItemId: binding.inventoryItemId,
        quantity,
        reason: addonName ? `加購「${addonName}」` : "加購扣庫存",
        note: "預約加購扣庫存",
      });
    });
  });

  return lines;
}

/**
 * @param {*} error
 * @return {HttpsError}
 */
function mapInventoryError(error) {
  if (error instanceof HttpsError) {
    return error;
  }
  const message = error && error.message ?
    String(error.message) :
    "庫存操作失敗，請稍後再試";
  if (message.indexOf("庫存不足") >= 0 ||
      message.indexOf("已停用") >= 0 ||
      message.indexOf("僅允許整數") >= 0 ||
      message.indexOf("找不到對應庫存") >= 0) {
    return new HttpsError("failed-precondition", message);
  }
  return new HttpsError("internal", message);
}

exports.finalizeBookingAddonInventory = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入會員帳號");
      }

      const requestData = request.data || {};
      const shopId = normalizeString(requestData.shopId);
      const bookingId = normalizeString(requestData.bookingId);
      const userId = request.auth.uid;

      if (!shopId) {
        throw new HttpsError("invalid-argument", "缺少店家 ID");
      }
      if (!bookingId) {
        throw new HttpsError("invalid-argument", "缺少訂單 ID");
      }

      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      const addonRef = firestore
          .collection("shops")
          .doc(shopId)
          .collection("addons")
          .doc("main");

      const [bookingSnap, addonSnap, member] = await Promise.all([
        bookingRef.get(),
        addonRef.get(),
        isShopMember(shopId, userId),
      ]);

      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "找不到這筆訂單");
      }

      const booking = bookingSnap.data() || {};
      if (normalizeString(booking.shopId) !== shopId) {
        throw new HttpsError("permission-denied", "沒有權限操作此訂單");
      }

      const isOwner = normalizeString(booking.userId) === userId;
      if (!isOwner && !member) {
        throw new HttpsError("permission-denied", "沒有權限操作此訂單");
      }

      if (normalizeString(booking.status) === "cancelled" ||
          booking.cancelledAt) {
        return {ok: true, skipped: true, reason: "cancelled"};
      }

      const addonData = addonSnap.exists ? (addonSnap.data() || {}) : {};
      const lines = buildAddonDeductLines(booking, addonData);
      if (lines.length === 0) {
        return {ok: true, skipped: true, reason: "no-inventory"};
      }

      try {
        await firestore.runTransaction(async (transaction) => {
          const latestSnap = await transaction.get(bookingRef);
          if (!latestSnap.exists) {
            throw new Error("找不到這筆訂單");
          }
          const latest = latestSnap.data() || {};
          if (normalizeString(latest.status) === "cancelled" ||
              latest.cancelledAt) {
            return;
          }

          const prepared = await prepareMergedDeduct(transaction, {
            shopId,
            consumptionId: bookingAddonDeductId(bookingId),
            sourceType: "addon",
            sourceId: bookingId,
            movementType: "addon",
            note: "預約加購扣庫存",
            lines,
          });
          commitPreparedConsumption(transaction, prepared, userId);
        });
      } catch (error) {
        throw mapInventoryError(error);
      }

      return {ok: true, skipped: false};
    },
);
