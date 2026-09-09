// 檔案名稱：functions/daycare/daycare_addon.js
// 功能說明：安親加購依客製／每日分時段紅字規則重算，不信任前端金額與數量

const {HttpsError} = require("firebase-functions/v2/https");
const {
  ADDON_GROUP_KEYS,
  minutesOf,
  normalizeString,
  parseBool,
  serviceDateKey,
  toInt,
  taiwanDate,
} = require("./daycare_utils");
const {addonLineAmount} = require("./daycare_pricing");
const {roundQuantity} = require("../inventory/inventory_cost");

/**
 * @param {*} raw
 * @return {Array<string>}
 */
function parseApplicableServices(raw) {
  if (!Array.isArray(raw)) {
    return ["accommodation"];
  }
  const values = [];
  const seen = new Set();
  raw.forEach((item) => {
    const text = normalizeString(item);
    if ((text === "accommodation" || text === "daycare") && !seen.has(text)) {
      seen.add(text);
      values.push(text);
    }
  });
  return values.length ? values : ["accommodation"];
}

/**
 * @param {Object} item
 * @return {boolean}
 */
function appliesToDaycare(item) {
  return parseApplicableServices(item && item.applicableServices)
      .includes("daycare");
}

/**
 * @param {*} raw
 * @return {Array<string>}
 */
function uniqueIds(raw) {
  const out = [];
  const seen = new Set();
  const list = Array.isArray(raw) ? raw : [];
  list.forEach((item) => {
    let id = "";
    if (item && typeof item === "object") {
      id = normalizeString(item.id || item.label);
    } else {
      id = normalizeString(item);
    }
    if (!id || seen.has(id)) {
      return;
    }
    seen.add(id);
    out.push(id);
  });
  return out;
}

/**
 * @param {Date} date
 * @return {Date}
 */
function taiwanWall(date) {
  const local = taiwanDate(date);
  return new Date(Date.UTC(
      local.getUTCFullYear(),
      local.getUTCMonth(),
      local.getUTCDate(),
      local.getUTCHours(),
      local.getUTCMinutes(),
  ));
}

/**
 * @param {string} label
 * @param {Date} start
 * @param {Date} end
 * @return {boolean}
 */
function slotFullyInside(label, start, end) {
  const hhmm = normalizeString(label);
  if (!/^\d{1,2}:\d{2}$/.test(hhmm)) {
    return false;
  }
  const startTw = taiwanDate(start);
  const endTw = taiwanDate(end);
  const mins = minutesOf(hhmm);
  const hour = Math.floor(mins / 60);
  const minute = mins % 60;
  const slotOn = (tw) => new Date(Date.UTC(
      tw.getUTCFullYear(),
      tw.getUTCMonth(),
      tw.getUTCDate(),
      hour,
      minute,
  ));
  const startWall = taiwanWall(start);
  const endWall = taiwanWall(end);
  const inside = (slot) => slot.getTime() >= startWall.getTime() &&
    slot.getTime() < endWall.getTime();
  return inside(slotOn(startTw)) || inside(slotOn(endTw));
}

/**
 * @param {Object|null} data
 * @param {string} id
 * @return {Object|null}
 */
function findCatalogItem(data, id) {
  const target = normalizeString(id);
  if (!data || !target) {
    return null;
  }
  for (const key of ADDON_GROUP_KEYS) {
    const list = Array.isArray(data[key]) ? data[key] : [];
    for (const item of list) {
      if (normalizeString(item && item.id) === target) {
        return {item, groupKey: key};
      }
    }
  }
  return null;
}

/**
 * @param {Object} live
 * @param {Array<string>} keys
 * @param {Date} startAt
 * @param {Date} endAt
 * @return {Array<Object>}
 */
function matchSlots(live, keys, startAt, endAt) {
  const catalogSlots = Array.isArray(live.timeSlots) ? live.timeSlots : [];
  const matched = [];
  const seen = new Set();
  for (const key of keys) {
    const found = catalogSlots.find((slot) => {
      return normalizeString(slot && slot.id) === key ||
        normalizeString(slot && slot.label) === key;
    });
    if (!found) {
      return [];
    }
    const label = normalizeString(found.label);
    if (!slotFullyInside(label, startAt, endAt)) {
      return [];
    }
    const identity = normalizeString(found.id) || label;
    if (seen.has(identity)) {
      continue;
    }
    seen.add(identity);
    matched.push({
      id: normalizeString(found.id),
      label,
    });
  }
  return matched;
}

/**
 * @param {Object} params
 * @return {Object}
 */
function resolveDaycareAddonLine({
  catalogDoc,
  requested,
  orderPetIds,
  allowedAddonIds,
  startAt,
  endAt,
}) {
  const id = normalizeString(
      requested && (requested.id || requested.serviceId),
  );
  const found = findCatalogItem(catalogDoc, id);
  if (!found) {
    throw new HttpsError("failed-precondition", "加購服務無效");
  }
  const live = found.item;
  const groupKey = found.groupKey;
  if (!allowedAddonIds.includes(id) ||
      (Object.prototype.hasOwnProperty.call(live, "enabled") &&
        !parseBool(live.enabled)) ||
      !appliesToDaycare(live)) {
    throw new HttpsError("failed-precondition", "所選加購服務未開放安親");
  }
  const price = toInt(live.price, 0);
  const name = normalizeString(live.name || live.label);
  const type = normalizeString(live.type) || groupKey;
  const minutes = Math.round((endAt - startAt) / 60000);
  const pets = Array.isArray(orderPetIds) ? orderPetIds.map(normalizeString)
      .filter(Boolean) : [];

  if (groupKey === "customServices") {
    const selected = uniqueIds(requested.selectedPetIds);
    if (!selected.length) {
      throw new HttpsError("failed-precondition", "客製化服務請選擇寵物");
    }
    const order = new Set(pets);
    selected.forEach((petId) => {
      if (!order.has(petId)) {
        throw new HttpsError("failed-precondition", "所選寵物不屬於此訂單");
      }
    });
    const count = selected.length;
    const amount = price * count;
    return {
      id,
      name,
      type,
      price,
      count,
      quantity: count,
      selectedPetIds: selected,
      selectedTimeSlots: [],
      amount,
    };
  }

  if (groupKey === "dailyTimedServices") {
    const selectedPets = uniqueIds(requested.selectedPetIds);
    if (!selectedPets.length) {
      throw new HttpsError("failed-precondition", "每日分時段服務請選擇寵物");
    }
    const order = new Set(pets);
    selectedPets.forEach((petId) => {
      if (!order.has(petId)) {
        throw new HttpsError("failed-precondition", "所選寵物不屬於此訂單");
      }
    });
    const slotKeys = uniqueIds([
      ...(Array.isArray(requested.selectedTimeSlots) ?
        requested.selectedTimeSlots : []),
      ...(Array.isArray(requested.selectedSlotIds) ?
        requested.selectedSlotIds : []),
    ]);
    const selectedSlots = matchSlots(live, slotKeys, startAt, endAt);
    if (!selectedSlots.length) {
      throw new HttpsError(
          "failed-precondition",
          "每日分時段服務請選擇有效時段",
      );
    }
    const count = selectedPets.length * selectedSlots.length;
    const amount = price * count;
    return {
      id,
      name,
      type,
      price,
      count,
      quantity: count,
      slotCount: selectedSlots.length,
      selectedPetIds: selectedPets,
      selectedTimeSlots: selectedSlots,
      amount,
    };
  }

  const amount = addonLineAmount({
    price,
    daycareChargeMode: live.daycareChargeMode || "per_order",
    count: 1,
    slotCount: toInt(live.slotCount, 1),
  }, minutes, pets.length || 1);
  return {
    id,
    name,
    type,
    price,
    count: 1,
    quantity: 1,
    daycareChargeMode: live.daycareChargeMode || "per_order",
    selectedPetIds: uniqueIds(requested.selectedPetIds),
    selectedTimeSlots: [],
    amount,
  };
}

/**
 * @param {Object} catalogDoc
 * @param {Array<Object>} requestedAddons
 * @param {Array<string>} orderPetIds
 * @param {Array<string>} allowedAddonIds
 * @param {Date} startAt
 * @param {Date} endAt
 * @return {{addonSnapshot: Array<Object>, addonAmount: number}}
 */
function resolveDaycareAddons({
  catalogDoc,
  requestedAddons,
  orderPetIds,
  allowedAddonIds,
  startAt,
  endAt,
}) {
  const addons = Array.isArray(requestedAddons) ? requestedAddons : [];
  const seen = new Set();
  const addonSnapshot = [];
  let addonAmount = 0;
  addons.forEach((requested) => {
    const id = normalizeString(
        requested && (requested.id || requested.serviceId),
    );
    if (!id) {
      throw new HttpsError("failed-precondition", "加購服務無效");
    }
    if (seen.has(id)) {
      throw new HttpsError("failed-precondition", "加購服務重複");
    }
    seen.add(id);
    const line = resolveDaycareAddonLine({
      catalogDoc,
      requested,
      orderPetIds,
      allowedAddonIds,
      startAt,
      endAt,
    });
    addonAmount += line.amount;
    addonSnapshot.push(line);
  });
  return {addonSnapshot, addonAmount};
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
    result.push({inventoryItemId, quantityPerUnit});
  });
  return result;
}

/**
 * @param {Array<Object>} addonSnapshot
 * @param {Object} catalogDoc
 * @return {Array<Object>}
 */
function buildDaycareAddonDeductLines(addonSnapshot, catalogDoc) {
  const lines = [];
  (addonSnapshot || []).forEach((rawAddon) => {
    const found = findCatalogItem(
        catalogDoc,
        normalizeString(rawAddon && (rawAddon.id || rawAddon.serviceId)),
    );
    if (!found || found.item.useInventory !== true) {
      return;
    }
    const bindings = parseCatalogBindings(found.item.inventoryBindings);
    if (!bindings.length) {
      return;
    }
    const count = Math.max(1, toInt(rawAddon.count, 1));
    const addonName = normalizeString(rawAddon.name || found.item.name);
    bindings.forEach((binding) => {
      const quantity = roundQuantity(binding.quantityPerUnit * count);
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

module.exports = {
  appliesToDaycare,
  parseApplicableServices,
  slotFullyInside,
  uniqueIds,
  resolveDaycareAddons,
  resolveDaycareAddonLine,
  buildDaycareAddonDeductLines,
  findCatalogItem,
  serviceDateKey,
};
