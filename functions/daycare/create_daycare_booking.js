// 檔案名稱：functions/daycare/create_daycare_booking.js
// 功能說明：建立臨托訂單：後端重算價格、名額與占用，不信任前端金額

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  BOOKING_KIND_DAYCARE,
  generateBookingCode,
  hasShopPermission,
  isRootAdmin,
  loadDateOverride,
  isDateOpen,
  resolveDayHours,
  minutesOf,
  normalizeString,
  serviceDateKey,
  isDaycareEnabled,
  summarizePolicyForService,
  submittedServicePolicyVersion,
  acceptedServiceVersion,
  toDate,
  toInt,
  weekdayTaiwan,
  writeActionLog,
  parseBool,
} = require("./daycare_utils");
const {
  resolveDaycareAddons,
  buildDaycareAddonDeductLines,
} = require("./daycare_addon");
const {
  bookingSearchFields,
} = require("../search/normalize_fields");
const {
  resolveDailyCareEntitlement,
  filterNonDailyCareAddons,
  requestedAddonId,
} = require("../daily_care/daily_care_entitlement");
const {
  bookingAddonDeductId,
  prepareMergedDeduct,
  commitPreparedConsumption,
} = require("../inventory/inventory_consumption");
const {
  quote,
  quoteRoom,
  findRoomTypeSetting,
  depositAmount,
  SELECTABLE_PLAN_TYPES,
  isRoomBased,
  persistPricingMode,
  remainingFromPaid,
} = require("./daycare_pricing");
const {
  assertAvailable,
} = require("./daycare_occupancy");
const {
  validateAndNormalizeBookingSubmitAnswers,
  validateAndNormalizeAdminCreateAnswers,
} = require("./custom_form_answers");
const {calculateDaycareSurcharge} = require("./special_date_surcharge");
const {capSpendAmount, canSpend} = require("./daycare_points");
const {
  effectiveMethodIds,
  isCustomerMethodAvailable,
  isAdminCreateSelectable,
} = require("../payments/shop_payment_methods");
const {
  syncShopMemberCache,
  loadShopFormAnswers,
} = require("./sync_shop_member");

/**
 * @param {Object} settings
 * @param {Date} startAt
 * @param {Date} endAt
 * @param {boolean} isAdmin
 * @param {Object|null} override
 */
function assertSchedule(settings, startAt, endAt, isAdmin, override) {
  if (!(startAt instanceof Date) || !(endAt instanceof Date) ||
      Number.isNaN(startAt.getTime()) || Number.isNaN(endAt.getTime())) {
    throw new HttpsError("invalid-argument", "請選擇正確的臨托時間");
  }
  if (startAt.getTime() >= endAt.getTime()) {
    throw new HttpsError("invalid-argument", "送達時間不得晚於接回時間");
  }
  if (!isDateOpen(settings, override, startAt)) {
    throw new HttpsError("failed-precondition", "該日期不開放安親");
  }
  const hours = resolveDayHours(settings, override);
  const taiwanOffsetMs = 8 * 60 * 60 * 1000;
  const taiwanStart = new Date(startAt.getTime() + taiwanOffsetMs);
  const taiwanEnd = new Date(endAt.getTime() + taiwanOffsetMs);

  const startMin =
    taiwanStart.getUTCHours() * 60 + taiwanStart.getUTCMinutes();
  const endMin =
    taiwanEnd.getUTCHours() * 60 + taiwanEnd.getUTCMinutes();
  if (startMin < minutesOf(hours.earliestDropOff) ||
      endMin > minutesOf(hours.latestPickUp)) {
    throw new HttpsError("failed-precondition", "已超出安親營業時間");
  }
  if (hours.latestDropoffTime &&
      startMin > minutesOf(hours.latestDropoffTime)) {
    throw new HttpsError("failed-precondition", "已超過當日最晚送達時間");
  }
  const now = Date.now();
  if (!isAdmin) {
    const sameDay = serviceDateKey(startAt) ===
      serviceDateKey(new Date());
    if (sameDay && settings.allowSameDay === false) {
      throw new HttpsError("failed-precondition", "不可預約當日安親");
    }
    const dayHours = resolveDayHours(settings, override);
    if (sameDay &&
        nowMinOfDay() >= minutesOf(dayHours.latestPickUp)) {
      throw new HttpsError(
          "failed-precondition",
          "今日已超過最晚接回時間，請選擇其他日期",
      );
    }
    if (startAt.getTime() <= now) {
      throw new HttpsError("failed-precondition", "送達時間必須晚於現在時間");
    }
    const advanceHours = toInt(settings.minAdvanceHours, 0);
    if (advanceHours > 0 &&
        startAt.getTime() - now < advanceHours * 60 * 60 * 1000) {
      throw new HttpsError("failed-precondition", "需提前預約");
    }
  }
}

/**
 * @return {number}
 */
function nowMinOfDay() {
  const taiwanOffsetMs = 8 * 60 * 60 * 1000;
  const taiwanNow = new Date(Date.now() + taiwanOffsetMs);
  return taiwanNow.getUTCHours() * 60 + taiwanNow.getUTCMinutes();
}

/**
 * @param {string|undefined} raw
 * @return {string}
 */
function persistDaycareDepositType(raw) {
  const type = normalizeString(raw) || "none";
  if (type === "staff_decide") {
    return "none";
  }
  return type;
}

/**
 * @param {string|undefined} raw
 * @return {boolean}
 */
function daycareRequiresDeadline(raw) {
  const type = persistDaycareDepositType(raw);
  return type === "fixed" || type === "percent" || type === "full";
}

/**
 * @param {number} hours
 * @return {Date}
 */
function depositExpireAtFromHours(hours) {
  const ms = hours === 0 ? 60 * 1000 : hours * 60 * 60 * 1000;
  return new Date(Date.now() + ms);
}

/**
 * @param {Object} coupon
 * @param {Object} parts
 * @return {number}
 */
function daycareCouponAmount(coupon, parts) {
  const type = normalizeString(coupon.type);
  if (type === "freeStay") {
    return 0;
  }
  const afterCampaign = Math.max(0,
      parts.planAmount + parts.extraPetAmount + parts.addonAmount +
      parts.surchargeAmount - parts.campaignDiscountAmount);
  const applyTarget = normalizeString(coupon.applyTarget) || "total";
  let base = afterCampaign;
  if (applyTarget === "room") {
    base = Math.max(0, parts.planAmount - parts.campaignDiscountAmount);
  } else if (applyTarget === "roomAndPet") {
    base = Math.max(0,
        parts.planAmount + parts.extraPetAmount -
        parts.campaignDiscountAmount);
  } else if (applyTarget === "service") {
    const serviceId = normalizeString(coupon.serviceId);
    const match = (parts.addons || []).find((item) =>
      normalizeString(item.id) === serviceId);
    base = match ? toInt(match.amount || match.price, 0) : 0;
  }
  base = Math.min(base, afterCampaign);
  let amount = 0;
  if (type === "fixedAmount") {
    amount = Math.min(toInt(coupon.discountValue, 0), base);
  } else if (type === "percent") {
    amount = Math.round(base * Number(coupon.discountValue || 0) / 100);
    const cap = toInt(coupon.maximumDiscountAmount, 0);
    if (cap > 0 && amount > cap) {
      amount = cap;
    }
    amount = Math.min(Math.max(0, amount), base);
  } else if (type === "freeService") {
    const serviceId = normalizeString(coupon.serviceId);
    const match = (parts.addons || []).find((item) =>
      normalizeString(item.id) === serviceId);
    amount = match ? toInt(match.amount || match.price, 0) : 0;
  }
  return Math.min(Math.max(0, amount), afterCampaign);
}

/**
 * @param {Object} params
 * @return {Promise<Array<Object>>}
 */
async function hydrateDaycarePets(params) {
  const firestore = params.firestore;
  const userId = params.userId;
  const shopId = params.shopId;
  const petIds = Array.isArray(params.petIds) ? params.petIds : [];
  const clientPets = Array.isArray(params.clientPets) ? params.clientPets : [];
  const byId = {};
  clientPets.forEach((item) => {
    const id = normalizeString(item && (item.petId || item.id));
    if (id) {
      byId[id] = item;
    }
  });
  const out = [];
  for (const petId of petIds) {
    const liveSnap = await firestore.collection("user_profiles").doc(userId)
        .collection("pets").doc(petId).get();
    const live = liveSnap.exists ? (liveSnap.data() || {}) : {};
    const client = byId[petId] || {};
    const merged = {...live, ...client, petId};
    delete merged.customFormAnswersByShop;
    const shopAnswers = await loadShopFormAnswers(
        firestore, userId, petId, shopId,
    );
    if (shopAnswers &&
        (!shopAnswers.shopId || shopAnswers.shopId === shopId)) {
      merged.shopFormAnswers = shopAnswers;
    }
    out.push(merged);
  }
  return out;
}

/**
 * 訂單已成立後才同步；失敗只記 log，不可刪單。
 * @param {Object} params
 * @return {Promise<void>}
 */
async function syncMemberAfterDaycareBooking(params) {
  try {
    await syncShopMemberCache({
      firestore: params.firestore,
      FieldValue: admin.firestore.FieldValue,
      shopId: params.shopId,
      userId: params.userId,
      customer: {
        name: params.customerName,
        phone: params.customerPhone,
        address: params.data && params.data.address,
        emergencyContact: {
          name: normalizeString(params.data && params.data.emergencyName),
          phone: normalizeString(params.data && params.data.emergencyPhone),
          relation: normalizeString(params.data && params.data.relation),
          address: normalizeString(params.data && params.data.emergencyAddress),
          phone2: normalizeString(params.data && params.data.phone2),
        },
      },
      policy: {
        policyVersion: params.policyVersion || 0,
        policyTitle: params.policyTitle || "",
        policyAcceptedAt: params.termsAcceptedAt || null,
        termsType: "daycare",
        termsVersion: params.policyVersion || 0,
        termsTitle: params.policyTitle || "",
      },
    });
  } catch (error) {
    console.error("[createDaycareBooking] member sync failed", {
      shopId: params.shopId,
      userId: params.userId,
      bookingId: params.bookingId,
      message: error && error.message ? error.message : String(error),
    });
  }
}

/**
 * @param {Object} plan
 * @param {Date} startAt
 */
function assertPlanWindow(plan, startAt) {
  if (!plan || plan.enabled === false) {
    throw new HttpsError("failed-precondition", "安親方案未啟用");
  }
  const type = normalizeString(plan.type) || "hourly";
  if (!SELECTABLE_PLAN_TYPES.includes(type)) {
    throw new HttpsError("failed-precondition", "此方案類型已停用");
  }
  const weekdays = Array.isArray(plan.weekdays) ?
    plan.weekdays.map((item) => toInt(item, 0)) : [1, 2, 3, 4, 5, 6, 7];
  if (!weekdays.includes(weekdayTaiwan(startAt))) {
    throw new HttpsError("failed-precondition", "此方案不適用該星期");
  }
}

exports.createDaycareBooking = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const requestId = normalizeString(data.requestId);
      if (!shopId) {
        throw new HttpsError("invalid-argument", "缺少店家編號");
      }

      const firestore = admin.firestore();
      const shopSnap = await firestore.collection("shops").doc(shopId).get();
      if (!shopSnap.exists) {
        throw new HttpsError("not-found", "找不到店家");
      }
      const shopData = shopSnap.data() || {};
      const settingsSnap = await firestore.collection("shops").doc(shopId)
          .collection("daycare_settings").doc("main").get();
      const settings = settingsSnap.data() || {};

      const isStaff = await hasShopPermission(
          shopId, uid, "manage_daycare_bookings",
      ) || isRootAdmin(uid);
      const source = isStaff && normalizeString(data.source) === "admin" ?
        "admin" : "customer";

      if (!isDaycareEnabled(shopData, settings)) {
        throw new HttpsError("failed-precondition", "店家目前未開放安親服務");
      }
      const availablePaymentMethods = effectiveMethodIds(shopData);
      if (!availablePaymentMethods.length) {
        throw new HttpsError(
            "failed-precondition",
            "店家目前未提供可用付款方式，請聯絡店家",
        );
      }
      const paymentMethod = normalizeString(data.paymentMethod);
      if (!isCustomerMethodAvailable(shopData, paymentMethod)) {
        throw new HttpsError(
            "failed-precondition",
            "請選擇有效的付款方式",
        );
      }

      const userId = source === "admin" ?
        normalizeString(data.userId) : uid;
      if (source === "admin" && !userId) {
        throw new HttpsError("invalid-argument", "找不到會員資料");
      }
      if (source === "admin" && !isAdminCreateSelectable(paymentMethod)) {
        throw new HttpsError(
            "failed-precondition",
            "手動建單請選擇到店付款或銀行轉帳",
        );
      }

      const memberSnap = await firestore.collection("shops").doc(shopId)
          .collection("members").doc(userId).get();
      if (source !== "admin" && memberSnap.exists &&
          memberSnap.data().blacklisted === true) {
        throw new HttpsError("failed-precondition", "此會員目前無法預約安親");
      }

      const startAt = toDate(data.scheduledStartAt) ||
        toDate(data.startAt);
      const endAt = toDate(data.scheduledEndAt) || toDate(data.endAt);
      const termsAcceptedAt = toDate(data.termsAcceptedAt) ||
        toDate(data.policyAcceptedAt);
      if (!startAt || !endAt) {
        throw new HttpsError("invalid-argument", "請選擇正確的安親時間");
      }
      const dateOverride = await loadDateOverride(firestore, shopId, startAt);
      assertSchedule(
          settings, startAt, endAt, source === "admin", dateOverride,
      );

      const petIds = Array.isArray(data.petIds) ?
        data.petIds.map((id) => normalizeString(id)).filter(Boolean) : [];
      if (petIds.length < toInt(settings.minPets, 1) ||
          petIds.length > toInt(settings.maxPets, 3)) {
        throw new HttpsError("failed-precondition", "寵物數量不符合安親限制");
      }

      const roomBased = isRoomBased(settings);
      const sentPricingMode = normalizeString(data.pricingMode);
      if (sentPricingMode &&
          isRoomBased({pricingMode: sentPricingMode}) !== roomBased) {
        throw new HttpsError(
            "failed-precondition",
            "安親收費模式已變更，請重新選擇房型或方案。",
        );
      }
      const plans = Array.isArray(settings.plans) ? settings.plans : [];
      const planId = normalizeString(data.daycarePlanId || data.planId);
      const plan = plans.find((item) =>
        normalizeString(item && item.id) === planId) || {};
      if (!roomBased) {
        assertPlanWindow(plan, startAt);
      }

      const requestedRoomTypeId = normalizeString(
          data.requestedRoomTypeId || data.roomTypeId,
      );
      let requestedRoomSetting = null;
      if (roomBased) {
        requestedRoomSetting = findRoomTypeSetting(
            settings, requestedRoomTypeId,
        );
        if (!requestedRoomSetting || !parseBool(requestedRoomSetting.enabled)) {
          throw new HttpsError("failed-precondition", "請選擇可用的安親房型");
        }
      }
      const roomTypeId = "";
      const occupancyMode = "slot";
      const requiresRoom = true;
      const allowedAddonIds = Array.isArray(settings.allowedAddonIds) ?
        settings.allowedAddonIds.map((id) => normalizeString(id))
            .filter(Boolean) : [];
      const addonDoc = await firestore.collection("shops").doc(shopId)
          .collection("addons").doc("main").get();
      const catalogDoc = addonDoc.data() || {};

      const addons = Array.isArray(data.addons) ? data.addons : [];
      const minutes = Math.round((endAt - startAt) / 60000);
      const resolvedAddons = resolveDaycareAddons({
        catalogDoc,
        requestedAddons: filterNonDailyCareAddons(addons),
        orderPetIds: petIds,
        allowedAddonIds,
        startAt,
        endAt,
      });
      let addonSnapshot = resolvedAddons.addonSnapshot;
      let addonAmount = resolvedAddons.addonAmount;
      let dailyCareEntitlement = {};
      try {
        const dailyCare = resolveDailyCareEntitlement({
          setting: shopData.dailyCareSetting || {},
          isDaycare: true,
          shopDaycareOn: true,
          offerId: roomBased ? requestedRoomTypeId : planId,
          offerName: roomBased ? "" : (normalizeString(plan.name) || ""),
          addonId: normalizeString(data.dailyCareAddonId) ||
            requestedAddonId(addons),
          startDate: startAt,
          endDate: endAt || startAt,
        });
        dailyCareEntitlement = dailyCare.entitlement;
        if (dailyCare.addonLine) {
          addonSnapshot = addonSnapshot.concat([dailyCare.addonLine]);
          addonAmount += dailyCare.amount;
        }
      } catch (error) {
        throw new HttpsError(
            "failed-precondition",
            error && error.message ? error.message : "照護加購無法使用",
        );
      }

      const surSnap = await firestore.collection("shops").doc(shopId)
          .collection("special_date_surcharges")
          .where("enabled", "==", true).get();
      const surchargeCalc = calculateDaycareSurcharge(
          surSnap.docs.map((doc) => ({id: doc.id, ...(doc.data() || {})})),
          {
            serviceDate: serviceDateKey(startAt),
            isRoomBased: roomBased,
            roomTypeId: requestedRoomTypeId,
          },
      );
      const surchargeAmount = surchargeCalc.total;
      let discountAmount = toInt(data.discountAmount, 0);
      if (!surchargeCalc.allowCampaign) {
        discountAmount = 0;
      }

      const draftQuote = roomBased ? quoteRoom({
        roomSetting: requestedRoomSetting,
        startAt,
        endAt,
        petCount: petIds.length,
      }) : quote({
        settings,
        plan,
        startAt,
        endAt,
        petCount: petIds.length,
        roomTypeExtra: 0,
        addonAmount,
        surchargeAmount,
        discountAmount,
        couponAmount: 0,
        pointAmount: 0,
        overtimeAmount: 0,
        manualAdjust: source === "admin" ? toInt(data.manualAdjust, 0) : 0,
      });

      let couponId = "";
      let couponName = "";
      let couponAmount = 0;
      let couponRef = null;
      const requestedCouponId = normalizeString(data.couponId);
      if (settings.allowCoupon === true && requestedCouponId) {
        if (!surchargeCalc.allowCoupon) {
          throw new HttpsError("failed-precondition", "此特殊日期不可使用優惠券");
        }
        couponRef = firestore.collection("shops").doc(shopId)
            .collection("member_coupons").doc(requestedCouponId);
        const couponSnap = await couponRef.get();
        if (!couponSnap.exists) {
          throw new HttpsError("failed-precondition", "找不到優惠券");
        }
        const coupon = couponSnap.data() || {};
        if (normalizeString(coupon.userId) !== userId) {
          throw new HttpsError("failed-precondition", "此優惠券不屬於目前會員");
        }
        const couponStatus = normalizeString(coupon.status);
        const usedBookingId = normalizeString(coupon.usedBookingId);
        const bookingDocId = requestId || "";
        const reservedHere = couponStatus === "reserved" &&
          usedBookingId && bookingDocId && usedBookingId === bookingDocId;
        if (couponStatus !== "available" && !reservedHere) {
          throw new HttpsError("failed-precondition", "此優惠券目前無法使用");
        }
        const expireAt = toDate(coupon.expireAt);
        if (expireAt && expireAt.getTime() < Date.now()) {
          throw new HttpsError("failed-precondition", "優惠券已過期");
        }
        const couponStart = toDate(coupon.startAt);
        if (couponStart && couponStart.getTime() > Date.now()) {
          throw new HttpsError("failed-precondition", "優惠券尚未生效");
        }
        if (normalizeString(coupon.type) === "freeStay") {
          throw new HttpsError("failed-precondition", "住宿券不可用於安親");
        }
        const roomTypeIds = Array.isArray(coupon.roomTypeIds) ?
          coupon.roomTypeIds.map((id) => normalizeString(id)) : [];
        if (roomTypeIds.length > 0 &&
            !roomTypeIds.includes(normalizeString(requestedRoomTypeId))) {
          throw new HttpsError("failed-precondition", "此優惠券不適用所選安親房型");
        }
        const specialDateAllowsCoupon = surchargeCalc.allowCoupon;
        if (!specialDateAllowsCoupon) {
          throw new HttpsError("failed-precondition", "此特殊日期不可使用優惠券");
        }
        couponAmount = daycareCouponAmount(coupon, {
          planAmount: toInt(draftQuote.timeCharge, draftQuote.baseAmount),
          extraPetAmount: draftQuote.extraPetAmount,
          addonAmount,
          surchargeAmount,
          campaignDiscountAmount: toInt(draftQuote.discountAmount, 0),
          addons: addonSnapshot,
        });
        if (toInt(coupon.minimumAmount, 0) > 0 &&
            draftQuote.baseAmount + draftQuote.extraPetAmount + addonAmount +
            surchargeAmount < toInt(coupon.minimumAmount, 0)) {
          throw new HttpsError("failed-precondition", "未達優惠券最低消費");
        }
        couponId = requestedCouponId;
        couponName = normalizeString(coupon.name) ||
          normalizeString(data.couponName);
      }

      const pointSettingSnap = await firestore.collection("shops").doc(shopId)
          .collection("settings").doc("points").get();
      const pointSetting = pointSettingSnap.data() || {};
      let pointBalance = 0;
      const pointRef = userId ?
        firestore.collection("shops").doc(shopId)
            .collection("member_points").doc(userId) : null;
      if (pointRef) {
        const pointSnap = await pointRef.get();
        pointBalance = toInt(pointSnap.exists ? pointSnap.data().points : 0, 0);
      }
      let pointAmount = 0;
      if (canSpend(pointSetting) && source !== "admin") {
        const payable = roomBased ?
          Math.max(0, toInt(draftQuote.cappedRoomAmount, 0) + addonAmount +
            surchargeAmount +
            (source === "admin" ? toInt(data.manualAdjust, 0) : 0) -
            discountAmount - couponAmount) :
          Math.max(0, toInt(draftQuote.baseAmount, 0) +
            toInt(draftQuote.extraPetAmount, 0) + addonAmount +
            surchargeAmount +
            (source === "admin" ? toInt(data.manualAdjust, 0) : 0) -
            discountAmount - couponAmount);
        pointAmount = capSpendAmount({
          requested: toInt(data.pointAmount, 0),
          balance: pointBalance,
          payableAfterCoupon: payable,
          maxPerBooking: toInt(pointSetting.maximumPointsPerBooking, 0),
        });
      }

      const computed = roomBased ? (() => {
        const overtimeAmount = 0;
        const manualAdjust = source === "admin" ?
          toInt(data.manualAdjust, 0) : 0;
        let total = toInt(draftQuote.cappedRoomAmount, 0) + addonAmount +
          surchargeAmount + overtimeAmount + manualAdjust -
          discountAmount - couponAmount - pointAmount;
        if (total < 0) {
          total = 0;
        }
        const deposit = depositAmount(settings, total);
        return {
          durationMinutes: minutes,
          baseAmount: draftQuote.baseAmount,
          extraPetAmount: draftQuote.extraPetAmount,
          roomTypeExtra: draftQuote.extraTimeAmount || 0,
          addonAmount,
          surchargeAmount,
          discountAmount,
          couponAmount,
          pointAmount,
          overtimeAmount,
          manualAdjust,
          totalAmount: total,
          depositAmount: deposit,
          remainingAmount: Math.max(0, total - deposit),
          extraTimeAmount: draftQuote.extraTimeAmount || 0,
          extraMinutes: draftQuote.extraMinutes || 0,
          extraUnits: draftQuote.extraUnits || 0,
          includedMinutes: draftQuote.includedMinutes || 0,
          extraBillingMinutes: draftQuote.extraBillingMinutes || 60,
          extraPetCount: draftQuote.extraPetCount || 0,
          timeCharge: draftQuote.timeCharge || 0,
          maxBaseCharge: draftQuote.maxBaseCharge || 0,
          uncappedTimeCharge: draftQuote.uncappedTimeCharge || 0,
        };
      })() : quote({
        settings,
        plan,
        startAt,
        endAt,
        petCount: petIds.length,
        roomTypeExtra: 0,
        addonAmount,
        surchargeAmount,
        discountAmount,
        couponAmount,
        pointAmount,
        overtimeAmount: 0,
        manualAdjust: source === "admin" ? toInt(data.manualAdjust, 0) : 0,
      });
      const estimateTotalPrice = computed.totalAmount;

      const availability = await assertAvailable(firestore, {
        shopId,
        startAt,
        endAt,
        petIds,
        roomId: "",
        roomTypeId,
        occupancyMode,
        dailyMaxPets: 0,
        blockUntilCleaned: true,
      });
      if (!availability.ok) {
        throw new HttpsError("failed-precondition", availability.reason);
      }

      const bookingRef = requestId ?
        firestore.collection("bookings").doc(requestId) :
        firestore.collection("bookings").doc();

      const existing = await bookingRef.get();
      if (existing.exists) {
        await syncMemberAfterDaycareBooking({
          firestore,
          shopId,
          userId,
          customerName: normalizeString(data.customerName) || "會員",
          customerPhone: normalizeString(data.customerPhone),
          data,
          policyVersion: toInt((existing.data() || {}).policyVersion, 0),
          policyTitle: normalizeString((existing.data() || {}).policyTitle),
          termsAcceptedAt: (existing.data() || {}).policyAcceptedAt || null,
          bookingId: bookingRef.id,
        });
        return {bookingId: bookingRef.id, reused: true};
      }

      const customFormSnap = await firestore.collection("shops").doc(shopId)
          .collection("custom_forms").doc("booking_submit").get();
      const customFormChecked = validateAndNormalizeBookingSubmitAnswers({
        form: customFormSnap.exists ? customFormSnap.data() : null,
        payloadAnswers: data.customFormAnswers,
        source,
      });
      if (customFormChecked.error) {
        throw new HttpsError(
            "failed-precondition",
            customFormChecked.error,
        );
      }
      let adminCustomFormChecked = {snapshot: null, error: null};
      if (source === "admin") {
        const adminFormSnap = await firestore.collection("shops").doc(shopId)
            .collection("custom_forms").doc("admin_create").get();
        adminCustomFormChecked = validateAndNormalizeAdminCreateAnswers({
          form: adminFormSnap.exists ? adminFormSnap.data() : null,
          payloadAnswers: data.adminCustomFormAnswers,
        });
        if (adminCustomFormChecked.error) {
          throw new HttpsError(
              "failed-precondition",
              adminCustomFormChecked.error,
          );
        }
      }

      const status = "pending";

      const customerName = normalizeString(data.customerName) || "會員";
      const customerPhone = normalizeString(data.customerPhone);
      const policySnap = await firestore.collection("shops").doc(shopId)
          .collection("policies").doc("checkin_policy").get();
      const policySummary = summarizePolicyForService(
          policySnap.data() || null, "daycare",
      );
      let policySignMethod = normalizeString(data.policySignMethod);
      if (policySummary.required) {
        if (source === "admin") {
          if (!["member_online", "staff_witness", "paper"].includes(
              policySignMethod,
          )) {
            throw new HttpsError(
                "failed-precondition",
                "請記錄安親條款簽署方式",
            );
          }
          if (policySignMethod === "member_online") {
            const acc = await firestore.collection("users").doc(userId)
                .collection("policy_acceptances").doc(shopId).get();
            if (acceptedServiceVersion(acc.data() || {}, "daycare") !==
                policySummary.version) {
              throw new HttpsError(
                  "failed-precondition",
                  "會員尚未同意目前安親條款",
              );
            }
          }
        } else {
          policySignMethod = "member_online";
          const submittedVersion = submittedServicePolicyVersion(data);
          const acc = await firestore.collection("users").doc(userId)
              .collection("policy_acceptances").doc(shopId).get();
          const acceptedVersion = acceptedServiceVersion(
              acc.data() || {}, "daycare",
          );
          if (submittedVersion !== policySummary.version &&
              acceptedVersion !== policySummary.version) {
            throw new HttpsError(
                "failed-precondition",
                "安親條款已更新，請重新閱讀並同意。",
            );
          }
          if (acceptedVersion !== policySummary.version) {
            throw new HttpsError(
                "failed-precondition",
                "安親條款已更新，請重新閱讀並同意。",
            );
          }
        }
      }
      const policyVersion = policySummary.required ?
        policySummary.version : 0;
      const policyTitle = policySummary.title || "安親須知";

      const hydratedPets = await hydrateDaycarePets({
        firestore,
        userId,
        shopId,
        petIds,
        clientPets: Array.isArray(data.pets) ? data.pets : [],
      });

      let requestedRoomTypeName = normalizeString(data.requestedRoomTypeName);
      if (roomBased && requestedRoomTypeId && !requestedRoomTypeName) {
        const typeSnap = await firestore.collection("shops").doc(shopId)
            .collection("room_types").doc(requestedRoomTypeId).get();
        requestedRoomTypeName =
          normalizeString((typeSnap.data() || {}).name) || requestedRoomTypeId;
      }

      await firestore.runTransaction(async (transaction) => {
        const again = await transaction.get(bookingRef);
        if (again.exists) {
          return;
        }
        if (couponRef) {
          const couponInTx = await transaction.get(couponRef);
          if (!couponInTx.exists) {
            throw new HttpsError("failed-precondition", "找不到優惠券");
          }
        }
        let spendLogRef = null;
        let currentPoints = 0;
        if (pointAmount > 0 && pointRef) {
          const pointInTx = await transaction.get(pointRef);
          currentPoints = toInt(
              pointInTx.exists ? pointInTx.data().points : 0, 0,
          );
          if (currentPoints < pointAmount) {
            throw new HttpsError("failed-precondition", "點數餘額不足");
          }
          spendLogRef = firestore.collection("shops").doc(shopId)
              .collection("member_point_logs")
              .doc(`spend_booking_${bookingRef.id}`);
          const spendSnap = await transaction.get(spendLogRef);
          if (spendSnap.exists) {
            throw new HttpsError("already-exists", "此訂單已折抵點數");
          }
        }
        const preparedInv = await prepareMergedDeduct(transaction, {
          shopId,
          consumptionId: bookingAddonDeductId(bookingRef.id),
          sourceType: "addon",
          sourceId: bookingRef.id,
          movementType: "addon",
          note: "預約加購扣庫存",
          lines: buildDaycareAddonDeductLines(addonSnapshot, catalogDoc),
        });
        if (pointAmount > 0 && pointRef) {
          transaction.set(pointRef, {
            points: currentPoints - pointAmount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          transaction.set(spendLogRef, {
            shopId,
            userId,
            bookingId: bookingRef.id,
            type: "spend",
            source: "daycare_booking",
            pointsChange: -pointAmount,
            amount: pointAmount,
            snapshot: {
              pointAmount,
              totalAmount: computed.totalAmount,
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        const bookingCode = await generateBookingCode(transaction, shopId);
        transaction.set(bookingRef, {
          requestId: requestId || bookingRef.id,
          bookingId: bookingRef.id,
          bookingCode,
          bookingKind: BOOKING_KIND_DAYCARE,
          shopId,
          shopName: shopData.name || "",
          userId,
          source,
          customerName,
          customerPhone,
          address: normalizeString(data.address),
          emergencyContact: {
            name: normalizeString(data.emergencyName),
            phone: normalizeString(data.emergencyPhone),
            relation: normalizeString(data.relation),
            address: normalizeString(data.emergencyAddress),
            phone2: normalizeString(data.phone2),
          },
          petIds,
          pets: hydratedPets,
          serviceType: BOOKING_KIND_DAYCARE,
          serviceDate: serviceDateKey(startAt),
          scheduledStartAt: admin.firestore.Timestamp.fromDate(startAt),
          scheduledEndAt: admin.firestore.Timestamp.fromDate(endAt),
          startDate: admin.firestore.Timestamp.fromDate(startAt),
          endDate: admin.firestore.Timestamp.fromDate(endAt),
          nights: 0,
          actualStartAt: null,
          actualEndAt: null,
          daycarePlanId: roomBased ? "" : (plan.id || ""),
          daycarePlanSnapshot: roomBased ? {} : plan,
          daycarePlanName: roomBased ? "" : (normalizeString(plan.name) || ""),
          daycarePricingSnapshot: computed,
          pricingMode: persistPricingMode(settings),
          estimateTotalPrice,
          quotedTotalPrice: computed.totalAmount,
          totalAmount: computed.totalAmount,
          priceQuoteLocked: true,
          priceConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
          roomTypeId: "",
          roomTypeName: "",
          roomTypeNameSnapshot: "",
          requestedRoomTypeId,
          requestedRoomTypeName,
          requestedRoomTypePriceSnapshot: roomBased ?
            (requestedRoomSetting || {}) : {},
          roomId: null,
          roomName: null,
          roomNumberSnapshot: "",
          assignStatus: "unassigned",
          requiresRoom,
          occupancyMode,
          cleaningRequired: true,
          addons: addonSnapshot,
          dailyCareEntitlement,
          note: normalizeString(data.note),
          adminOrderSource: source === "admin" ?
            (normalizeString(data.adminOrderSource) || "電話預約") : "",
          ...(customFormChecked.snapshot ? {
            customFormAnswers: {
              ...customFormChecked.snapshot,
              submittedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          } : {}),
          ...(adminCustomFormChecked.snapshot ? {
            adminCustomFormAnswers: {
              ...adminCustomFormChecked.snapshot,
              submittedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          } : {}),
          totalPrice: computed.totalAmount,
          originalTotal: computed.baseAmount + computed.extraPetAmount +
            computed.roomTypeExtra + computed.addonAmount +
            computed.surchargeAmount,
          specialDateSurchargeAmount: computed.surchargeAmount,
          specialDateSurchargeDetails: surchargeCalc.details,
          discountAmount: computed.discountAmount,
          discountCampaignId: normalizeString(data.discountCampaignId),
          discountCampaignName: normalizeString(data.discountCampaignName),
          couponId,
          couponName,
          couponDiscountAmount: computed.couponAmount,
          pointAmount: computed.pointAmount,
          overtimeMinutes: 0,
          overtimeAmount: 0,
          manualAdjust: computed.manualAdjust,
          depositAmount: computed.depositAmount,
          requiredPaymentAmount: computed.depositAmount > 0 ?
            computed.depositAmount : 0,
          depositPercent: persistDaycareDepositType(settings.depositType) ===
            "percent" ? toInt(settings.depositValue, 0) : null,
          daycareDepositType: persistDaycareDepositType(settings.depositType),
          depositType: persistDaycareDepositType(settings.depositType),
          depositExpireHours: daycareRequiresDeadline(settings.depositType) ?
            toInt(settings.depositExpireHours, 12) : null,
          depositExpireAt: daycareRequiresDeadline(settings.depositType) ?
            admin.firestore.Timestamp.fromDate(
                depositExpireAtFromHours(
                    toInt(settings.depositExpireHours, 12),
                ),
            ) : null,
          depositPaid: false,
          depositStatus: computed.depositAmount > 0 ? "unpaid" : "",
          paymentMethod: normalizeString(data.paymentMethod),
          payAmountType: normalizeString(data.payAmountType) ||
            (computed.depositAmount > 0 ? "deposit" : "full"),
          paidAmount: 0,
          remainingAmount: remainingFromPaid(computed.totalAmount, 0),
          paymentStatus: "unpaid",
          refundAmount: 0,
          refundStatus: "",
          convertedToAccommodation: false,
          convertedBookingId: "",
          convertedFromDaycareBookingId: "",
          conversionCreditAmount: 0,
          conversionPolicy: "",
          noShowAt: null,
          completedAt: null,
          policyId: "checkin_policy",
          policyVersion,
          policyVersionId: policySummary.required ? `v${policyVersion}` : "",
          policyTitle,
          termsAcceptedAt: termsAcceptedAt ?
            admin.firestore.Timestamp.fromDate(termsAcceptedAt) : null,
          policyAcceptedAt: termsAcceptedAt ?
            admin.firestore.Timestamp.fromDate(termsAcceptedAt) :
            (policySummary.required ?
              admin.firestore.FieldValue.serverTimestamp() : null),
          policyKind: "daycare",
          policyServiceType: "daycare",
          policySignMethod: policySummary.required ? policySignMethod : "",
          policySignedByUid: source === "admin" ? uid : userId,
          policySnapshotVersion: policyVersion,
          createdByUid: source === "admin" ? uid : "",
          createdByEmail: source === "admin" ?
            normalizeString((request.auth.token || {}).email) : "",
          status,
          bankName: shopData.bankName || "",
          accountName: shopData.accountName || "",
          accountNumber: shopData.accountNumber || "",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          ...bookingSearchFields({
            customerName,
            customerPhone,
            bookingCode,
            pets: hydratedPets,
          }),
        });
        if (!preparedInv.skip) {
          commitPreparedConsumption(transaction, preparedInv, uid);
        }
        if (couponRef && couponId) {
          transaction.update(couponRef, {
            status: "reserved",
            usedBookingId: bookingRef.id,
            usedAt: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      await writeActionLog({
        shopId,
        targetId: bookingRef.id,
        action: "daycare_created",
        operatorUid: uid,
        operatorRole: source === "admin" ? "staff" : "member",
        payload: {
          totalPrice: computed.totalAmount,
          planId: normalizeString(plan.id),
          status,
        },
      });

      await syncMemberAfterDaycareBooking({
        firestore,
        shopId,
        userId,
        customerName,
        customerPhone,
        data,
        policyVersion,
        policyTitle,
        termsAcceptedAt: termsAcceptedAt ?
          admin.firestore.Timestamp.fromDate(termsAcceptedAt) :
          admin.firestore.FieldValue.serverTimestamp(),
        bookingId: bookingRef.id,
      });

      return {
        bookingId: bookingRef.id,
        totalPrice: computed.totalAmount,
        estimateTotalPrice,
        depositAmount: computed.depositAmount,
        status,
        pricingMode: persistPricingMode(settings),
      };
    },
);
