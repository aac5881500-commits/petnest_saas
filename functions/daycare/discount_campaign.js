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

function calculateCampaign(campaign, input, now) {
  if (!campaign || campaign.enabled !== true) {
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

module.exports = {
  parseApplicableServices,
  findBestDaycareCampaign,
  calculateCampaign,
  nights,
};
