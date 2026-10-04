// 檔案名稱：functions/daycare/discount_campaign.js
// 功能說明：安親自動優惠與 Flutter DiscountCampaignCalculator 對齊。
// 舊活動沒有 applicableServices 時僅住宿，不可自動套用安親。

function toInt(value, fallback = 0) {
  const n = Number(value);
  if (!Number.isFinite(n)) {
    return fallback;
  }
  return Math.round(n);
}

function dateOnly(value) {
  const d = value instanceof Date ? value : new Date(value);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function parseApplicableServices(raw) {
  if (!Array.isArray(raw)) {
    return ["accommodation"];
  }
  const values = [...new Set(raw.map((item) => String(item || "").trim())
      .filter((item) => item === "accommodation" || item === "daycare"))];
  return values.length ? values : ["accommodation"];
}

function appliesTo(campaign, serviceType) {
  return parseApplicableServices(campaign.applicableServices)
      .includes(serviceType);
}

function nights(input) {
  const start = dateOnly(input.checkInDate);
  const end = dateOnly(input.checkOutDate);
  const diff = Math.round((end - start) / 86400000);
  return diff < 0 ? 0 : diff;
}

function withinPeriod(campaign, now) {
  if (campaign.type === "stayDate") {
    return true;
  }
  const start = campaign.startAt ? new Date(campaign.startAt) : null;
  const end = campaign.endAt ? new Date(campaign.endAt) : null;
  if (start && now < start) {
    return false;
  }
  if (end && now > end) {
    return false;
  }
  return true;
}

function matchesStayDate(campaign, input) {
  if (!campaign.startAt || !campaign.endAt) {
    return false;
  }
  const campaignStart = dateOnly(campaign.startAt);
  const campaignEnd = dateOnly(campaign.endAt);
  const checkIn = dateOnly(input.checkInDate);
  const checkOut = dateOnly(input.checkOutDate);
  const matchType = campaign.dateMatchType || "matchingStayDates";
  if (matchType === "checkInDate") {
    return checkIn >= campaignStart && checkIn <= campaignEnd;
  }
  if (matchType === "entireStay") {
    const last = new Date(checkOut.getTime() - 86400000);
    return checkIn >= campaignStart && last <= campaignEnd;
  }
  return checkIn < new Date(campaignEnd.getTime() + 86400000) &&
      checkOut > campaignStart;
}

function matchesType(campaign, input) {
  switch (campaign.type) {
    case "longStay":
      return false;
    case "newMember":
      if (campaign.newMemberEligibilityMode === "noPreviousBooking") {
        return input.isFirstBooking === true;
      }
      if (!input.memberJoinedAt || !campaign.createdAt) {
        return false;
      }
      return new Date(input.memberJoinedAt) >= new Date(campaign.createdAt);
    case "googleReview":
      return input.hasVerifiedGoogleReview === true;
    case "stayDate":
      return matchesStayDate(campaign, input);
    case "roomType": {
      const ids = Array.isArray(campaign.roomTypeIds) ? campaign.roomTypeIds : [];
      return ids.length > 0 && ids.includes(input.roomTypeId);
    }
    case "minimumAmount": {
      const total = toInt(input.roomAmount) + toInt(input.petAmount) +
          toInt(input.extraServiceAmount);
      return toInt(campaign.minimumAmount) > 0 &&
          total >= toInt(campaign.minimumAmount);
    }
    case "limitedTime":
      return true;
    default:
      return false;
  }
}

function memberUsageOk(campaign, input) {
  const limit = toInt(campaign.memberUsageLimit, 1);
  if (campaign.type === "newMember") {
    if (limit <= 0) {
      return true;
    }
  }
  if (limit <= 0) {
    return true;
  }
  const used = toInt((input.memberCampaignUsage || {})[campaign.id], 0);
  return used < limit;
}

function discountBase(campaign, input) {
  const room = toInt(input.roomAmount);
  const pet = toInt(input.petAmount);
  const extra = toInt(input.extraServiceAmount);
  switch (campaign.applyTarget) {
    case "roomAndPet":
      return room + pet;
    case "total":
      return room + pet + extra;
    default:
      return room;
  }
}

function calculateAmount(campaign, base) {
  let amount = 0;
  if (campaign.valueType === "percent") {
    amount = base * Number(campaign.discountValue || 0) / 100;
    const cap = toInt(campaign.maximumDiscountAmount);
    if (cap > 0 && amount > cap) {
      amount = cap;
    }
  } else {
    amount = Number(campaign.discountValue || 0);
  }
  if (amount > base) {
    amount = base;
  }
  return Math.round(amount);
}

function totalUsageOk(campaign) {
  const limit = toInt(campaign.totalUsageLimit, 0);
  if (limit <= 0) {
    return true;
  }
  return toInt(campaign.usedCount, 0) < limit;
}

function calculateCampaign(campaign, input, now) {
  if (!campaign || campaign.enabled !== true) {
    return null;
  }
  if (!totalUsageOk(campaign)) {
    return null;
  }
  if (!appliesTo(campaign, "daycare")) {
    return null;
  }
  if (campaign.type === "longStay") {
    return null;
  }
  if (!withinPeriod(campaign, now)) {
    return null;
  }
  if (!memberUsageOk(campaign, input)) {
    return null;
  }
  if (!matchesType(campaign, input)) {
    return null;
  }
  const base = discountBase(campaign, input);
  if (base <= 0) {
    return null;
  }
  const discountAmount = calculateAmount(campaign, base);
  if (discountAmount <= 0) {
    return null;
  }
  return {campaign, discountAmount};
}

function findBestDaycareCampaign({campaigns, input, now}) {
  const when = now || new Date();
  const results = (campaigns || [])
      .map((campaign) => calculateCampaign(campaign, input, when))
      .filter((item) => item && item.discountAmount > 0);
  results.sort((a, b) => b.discountAmount - a.discountAmount);
  return results[0] || null;
}

function dateKey(value) {
  const day = dateOnly(value);
  const y = String(day.getFullYear());
  const m = String(day.getMonth() + 1).padStart(2, "0");
  const d = String(day.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function onOrAfter(first, second) {
  return dateKey(first) >= dateKey(second);
}

function onOrBefore(first, second) {
  return dateKey(first) <= dateKey(second);
}

function remainingNewMemberNights(campaign, input) {
  const total = toInt(campaign.newMemberDiscountNights, 0);
  if (total <= 0) {
    return 0;
  }
  const used = toInt((input.memberCampaignUsedNights || {})[campaign.id], 0);
  return Math.max(0, total - Math.max(0, used));
}

function memberJoinedOk(campaign, input) {
  if (campaign.newMemberEligibilityMode === "noPreviousBooking") {
    return input.isFirstBooking === true;
  }
  if (!input.memberJoinedAt || !campaign.createdAt) {
    return false;
  }
  return new Date(input.memberJoinedAt) >= new Date(campaign.createdAt);
}

function accommodationTypeOk(campaign, input) {
  switch (campaign.type) {
    case "longStay":
      return toInt(campaign.minimumNights, 0) > 0 &&
        nights(input) >= toInt(campaign.minimumNights, 0);
    case "newMember":
      return remainingNewMemberNights(campaign, input) > 0 &&
        (toInt((input.memberCampaignUsedNights || {})[campaign.id], 0) > 0 ||
          memberJoinedOk(campaign, input));
    case "googleReview":
      return input.hasVerifiedGoogleReview === true;
    case "stayDate":
      return matchesStayDate(campaign, input);
    case "roomType": {
      const ids = Array.isArray(campaign.roomTypeIds) ?
        campaign.roomTypeIds : [];
      if (!ids.includes(input.roomTypeId)) {
        return false;
      }
      if (campaign.limitStayDate !== true) {
        return true;
      }
      if (!campaign.stayStartAt || !campaign.stayEndAt) {
        return false;
      }
      const stayEnd = dateOnly(campaign.stayEndAt);
      stayEnd.setHours(23, 59, 59, 999);
      return onOrAfter(input.checkInDate, campaign.stayStartAt) &&
        dateOnly(input.checkOutDate) <= stayEnd;
    }
    case "minimumAmount": {
      const total = toInt(input.roomAmount) + toInt(input.petAmount) +
        toInt(input.extraServiceAmount);
      return toInt(campaign.minimumAmount) > 0 &&
        total >= toInt(campaign.minimumAmount);
    }
    case "limitedTime":
      return true;
    default:
      return false;
  }
}

function accommodationMemberOk(campaign, input) {
  if (campaign.type === "newMember") {
    return remainingNewMemberNights(campaign, input) > 0;
  }
  const limit = toInt(campaign.memberUsageLimit, 1);
  if (limit <= 0) {
    return true;
  }
  const used = toInt((input.memberCampaignUsage || {})[campaign.id], 0);
  return used < limit;
}

/**
 * 住宿套用客戶指定的活動。金額以後端為準，不讀客戶 discountAmount。
 * 不符合時回傳 null。
 * @param {Object} campaign
 * @param {Object} input
 * @param {Date} now
 * @return {Object|null}
 */
function quoteAccommodationCampaign(campaign, input, now) {
  if (!campaign || campaign.enabled !== true) {
    return null;
  }
  if (!totalUsageOk(campaign)) {
    return null;
  }
  if (!appliesTo(campaign, "accommodation")) {
    return null;
  }
  const when = now || new Date();
  if (!withinPeriod(campaign, when)) {
    return null;
  }
  if (!accommodationMemberOk(campaign, input)) {
    return null;
  }
  if (!accommodationTypeOk(campaign, input)) {
    return null;
  }
  const stayNights = nights(input);
  let discountUsedNights = 0;
  let base = discountBase(campaign, input);
  if (campaign.type === "newMember") {
    const remaining = remainingNewMemberNights(campaign, input);
    discountUsedNights = Math.min(stayNights, remaining);
    if (discountUsedNights <= 0 || stayNights <= 0) {
      return null;
    }
    base = (toInt(input.roomAmount) / stayNights) * discountUsedNights;
  }
  if (campaign.type === "stayDate" &&
      (campaign.dateMatchType || "matchingStayDates") === "matchingStayDates") {
    if (!campaign.startAt || !campaign.endAt || stayNights <= 0) {
      return null;
    }
    let matching = 0;
    const cursor = dateOnly(input.checkInDate);
    const end = dateOnly(input.checkOutDate);
    const start = dateOnly(campaign.startAt);
    const last = dateOnly(campaign.endAt);
    while (cursor < end) {
      if (onOrAfter(cursor, start) && onOrBefore(cursor, last)) {
        matching += 1;
      }
      cursor.setDate(cursor.getDate() + 1);
    }
    if (matching <= 0) {
      return null;
    }
    base = (toInt(input.roomAmount) / stayNights) * matching;
  }
  if (base <= 0) {
    return null;
  }
  const priced = {
    ...campaign,
    discountValue: campaign.type === "newMember" &&
      discountUsedNights > 0 &&
      campaign.valueType !== "percent" ?
      Number(campaign.discountValue || 0) * discountUsedNights :
      campaign.discountValue,
  };
  const discountAmount = calculateAmount(priced, base);
  if (discountAmount <= 0) {
    return null;
  }
  return {
    campaign,
    discountAmount,
    discountBaseAmount: base,
    discountUsedNights,
  };
}

function isOrderWindowOpen(campaign, now) {
  return withinPeriod(campaign, now || new Date());
}

module.exports = {
  parseApplicableServices,
  findBestDaycareCampaign,
  calculateCampaign,
  quoteAccommodationCampaign,
  isOrderWindowOpen,
  totalUsageOk,
  nights,
};
