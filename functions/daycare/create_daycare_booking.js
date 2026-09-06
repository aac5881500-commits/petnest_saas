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
  resolveDailyMaxPets,
  resolveDayHours,
  minutesOf,
  normalizeString,
  serviceDateKey,
  isDaycareEnabled,
  summarizePolicyForService,
  toDate,
  toInt,
  weekdayTaiwan,
  writeActionLog,
  flattenAddonCatalog,
  parseBool,
} = require("./daycare_utils");
const {
  addonLineAmount,
  quote,
  quoteRoom,
  findRoomTypeSetting,
  depositAmount,
  SELECTABLE_PLAN_TYPES,
  isRoomBased,
} = require("./daycare_pricing");
const {
  assertAvailable,
} = require("./daycare_occupancy");

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
  const minutes = Math.round((endAt - startAt) / 60000);
  if (minutes < toInt(settings.minDurationMinutes, 60)) {
    throw new HttpsError("failed-precondition", "未達最短安親時間");
  }
  if (minutes > toInt(settings.maxDurationMinutes, 480)) {
    throw new HttpsError("failed-precondition", "已超過最長安親時間");
  }
  if (settings.forbidOvernight !== false &&
      serviceDateKey(startAt) !== serviceDateKey(endAt)) {
    throw new HttpsError("failed-precondition", "此店家不接受跨日安親");
  }
  if (!isDateOpen(settings, override, startAt)) {
    throw new HttpsError("failed-precondition", "該日期不開放安親");
  }
  const hours = resolveDayHours(settings, override);
  if (settings.blockOutsideHours !== false) {
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
  }
  const now = Date.now();
  if (!isAdmin) {
    const sameDay = serviceDateKey(startAt) ===
      serviceDateKey(new Date());
    if (sameDay && settings.allowSameDay === false) {
      throw new HttpsError("failed-precondition", "不可預約當日安親");
    }
    const advanceHours = toInt(settings.minAdvanceHours, 0);
    if (advanceHours > 0 &&
        startAt.getTime() - now < advanceHours * 60 * 60 * 1000) {
      throw new HttpsError("failed-precondition", "需提前預約");
    }
  }
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
        throw new HttpsError("failed-precondition", "本店目前未開放安親服務");
      }

      const userId = source === "admin" ?
        (normalizeString(data.userId) || uid) : uid;

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
      const catalog = flattenAddonCatalog(addonDoc.data() || null);
      const catalogById = {};
      catalog.forEach((item) => {
        catalogById[item.id] = item;
      });

      const addons = Array.isArray(data.addons) ? data.addons : [];
      const minutes = Math.round((endAt - startAt) / 60000);
      let addonAmount = 0;
      const addonSnapshot = addons.map((addon) => {
        const id = normalizeString(addon.id);
        if (!id || !allowedAddonIds.includes(id) || !catalogById[id]) {
          throw new HttpsError("failed-precondition", "所選加購服務未開放安親");
        }
        const live = catalogById[id];
        const line = {
          id,
          name: live.name || normalizeString(addon.name),
          type: live.type || normalizeString(addon.type),
          price: live.price,
          count: toInt(addon.count, 1),
          daycareChargeMode: live.daycareChargeMode || "per_order",
          slotCount: toInt(addon.slotCount, live.slotCount),
        };
        const amount = addonLineAmount(line, minutes, petIds.length);
        addonAmount += amount;
        return {...line, amount};
      });

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
        surchargeAmount: toInt(data.specialDateSurchargeAmount, 0),
        discountAmount: toInt(data.discountAmount, 0),
        couponAmount: 0,
        pointAmount: toInt(data.pointAmount, 0),
        overtimeAmount: 0,
        manualAdjust: source === "admin" ? toInt(data.manualAdjust, 0) : 0,
      });

      let couponId = "";
      let couponName = "";
      let couponAmount = 0;
      let couponRef = null;
      const requestedCouponId = normalizeString(data.couponId);
      if (settings.allowCoupon === true && requestedCouponId) {
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
        const surchargeDetails =
          Array.isArray(data.specialDateSurchargeDetails) ?
            data.specialDateSurchargeDetails : [];
        const specialDateAllowsCoupon = surchargeDetails.every((item) =>
          !item || item.allowCoupon !== false);
        if (!specialDateAllowsCoupon) {
          throw new HttpsError("failed-precondition", "此特殊日期不可使用優惠券");
        }
        couponAmount = daycareCouponAmount(coupon, {
          planAmount: toInt(draftQuote.timeCharge, draftQuote.baseAmount),
          extraPetAmount: draftQuote.extraPetAmount,
          addonAmount,
          surchargeAmount: toInt(draftQuote.surchargeAmount, 0),
          campaignDiscountAmount: toInt(draftQuote.discountAmount, 0),
          addons: addonSnapshot,
        });
        if (toInt(coupon.minimumAmount, 0) > 0 &&
            draftQuote.baseAmount + draftQuote.extraPetAmount + addonAmount +
            draftQuote.surchargeAmount < toInt(coupon.minimumAmount, 0)) {
          throw new HttpsError("failed-precondition", "未達優惠券最低消費");
        }
        couponId = requestedCouponId;
        couponName = normalizeString(coupon.name) ||
          normalizeString(data.couponName);
      }

      const computed = roomBased ? (() => {
        const surchargeAmount = toInt(data.specialDateSurchargeAmount, 0);
        const discountAmount = toInt(data.discountAmount, 0);
        const pointAmount = toInt(data.pointAmount, 0);
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
        surchargeAmount: toInt(data.specialDateSurchargeAmount, 0),
        discountAmount: toInt(data.discountAmount, 0),
        couponAmount,
        pointAmount: toInt(data.pointAmount, 0),
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
        dailyMaxPets: resolveDailyMaxPets(settings, dateOverride),
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
        return {bookingId: bookingRef.id, reused: true};
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
            const byService = (acc.data() || {}).acceptedVersions || {};
            if (toInt(byService.daycare, 0) !== policySummary.version) {
              throw new HttpsError(
                  "failed-precondition",
                  "會員尚未同意目前安親條款",
              );
            }
          }
        } else {
          policySignMethod = "member_online";
          const submittedVersion = toInt(data.policyVersion, 0);
          if (submittedVersion !== policySummary.version) {
            throw new HttpsError(
                "failed-precondition",
                "條款已更新，請重新閱讀並同意",
            );
          }
          const acc = await firestore.collection("users").doc(userId)
              .collection("policy_acceptances").doc(shopId).get();
          const byService = (acc.data() || {}).acceptedVersions || {};
          if (toInt(byService.daycare, 0) !== policySummary.version) {
            throw new HttpsError(
                "failed-precondition",
                "請先閱讀並同意安親條款",
            );
          }
        }
      }
      const policyVersion = policySummary.required ?
        policySummary.version : 0;
      const policyTitle = policySummary.title || "安親須知";

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
          pets: Array.isArray(data.pets) ? data.pets : [],
          serviceType: BOOKING_KIND_DAYCARE,
          serviceDate: serviceDateKey(startAt),
          scheduledStartAt: admin.firestore.Timestamp.fromDate(startAt),
          scheduledEndAt: admin.firestore.Timestamp.fromDate(endAt),
          startDate: admin.firestore.Timestamp.fromDate(startAt),
          endDate: admin.firestore.Timestamp.fromDate(endAt),
          nights: 0,
          actualStartAt: null,
          actualEndAt: null,
          daycarePlanId: plan.id || "",
          daycarePlanSnapshot: plan,
          daycarePricingSnapshot: computed,
          pricingMode: roomBased ? "room_based" : "time_based",
          estimateTotalPrice,
          quotedTotalPrice: computed.totalAmount,
          priceQuoteLocked: true,
          priceConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
          roomTypeId: "",
          roomTypeName: "",
          roomTypeNameSnapshot: "",
          requestedRoomTypeId,
          requestedRoomTypeName,
          roomId: null,
          roomName: null,
          roomNumberSnapshot: "",
          assignStatus: "unassigned",
          requiresRoom,
          occupancyMode,
          cleaningRequired: true,
          addons: addonSnapshot,
          note: normalizeString(data.note),
          totalPrice: computed.totalAmount,
          originalTotal: computed.baseAmount + computed.extraPetAmount +
            computed.roomTypeExtra + computed.addonAmount +
            computed.surchargeAmount,
          specialDateSurchargeAmount: computed.surchargeAmount,
          specialDateSurchargeDetails:
            Array.isArray(data.specialDateSurchargeDetails) ?
              data.specialDateSurchargeDetails : [],
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
          paymentMethod: normalizeString(data.paymentMethod),
          payAmountType: normalizeString(data.payAmountType) ||
            (computed.depositAmount > 0 ? "deposit" : "full"),
          paidAmount: 0,
          remainingAmount: computed.remainingAmount != null ?
            computed.remainingAmount : computed.totalAmount,
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
          status,
          bankName: shopData.bankName || "",
          accountName: shopData.accountName || "",
          accountNumber: shopData.accountNumber || "",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
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

      return {
        bookingId: bookingRef.id,
        totalPrice: computed.totalAmount,
        estimateTotalPrice,
        depositAmount: computed.depositAmount,
        status,
        pricingMode: roomBased ? "room_based" : "time_based",
      };
    },
);
