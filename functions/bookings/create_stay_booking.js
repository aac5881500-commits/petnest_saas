// 檔案名稱：functions/bookings/create_stay_booking.js
// 功能說明：住宿建單／分房 transaction：共用房型可賣數與未分房保留

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  BOOKING_KIND_ACCOMMODATION,
  generateBookingCode,
  hasShopPermission,
  isRootAdmin,
  normalizeString,
  resolveOperatorIdentity,
  toDate,
  toInt,
  writeActionLogInTransaction,
} = require("../daycare/daycare_utils");
const {bookingSearchFields} = require("../search/normalize_fields");
const {stampSubmittedAt} = require("../daycare/custom_form_answers");
const {
  CHECKOUT_CLEANING_STATUS,
  newStayAutoCleaningSnapshot,
  stayAutoCleaningForRebuild,
  calendarBlocksRoom,
  canReleaseOwnedCalendar,
  commitRoomTypeHold,
  isManualCalendarStatus,
  loadStayRoomTypeHoldStates,
  remainingRoomsFromData,
  releaseStayRoomTypeHoldsInTransaction,
  roomPermanentlyUnsellable,
  stayCalendarPlan,
  stayNightKeys,
  stayReleaseDateKeys,
  ROOM_TYPE_SOLD_OUT,
} = require("../daycare/daycare_occupancy");
const {
  loadAppMemberState,
  prepareSpendDeduct,
  commitSpendDeduct,
} = require("../points/sync_booking_points");
const {
  quoteAccommodationCampaign,
} = require("../daycare/discount_campaign");
const {
  commitCampaignUsageReserve,
  readCampaignForUse,
  readCampaignUsageReserve,
  readCampaignUsedCount,
} = require("./campaign_usage");
const {computeEarnPoints} = require("../points/booking_points");
const {
  resolveDailyCareEntitlement,
  applyAuthoritativeCare,
  STAY_PAID_ID,
} = require("../daily_care/daily_care_entitlement");

/**
 * @param {Object} booking
 * @param {Object} data
 * @return {string}
 */
function requestedStayCareAddonId(booking, data) {
  const fromField = normalizeString(
      (booking && booking.dailyCareAddonId) ||
      (data && data.dailyCareAddonId),
  );
  if (fromField === STAY_PAID_ID || fromField === "1" || fromField === "true") {
    return STAY_PAID_ID;
  }
  const addons = Array.isArray(booking && booking.addons) ? booking.addons : [];
  for (let i = 0; i < addons.length; i++) {
    const item = addons[i] || {};
    const id = String(item.id || item.addonId || "").trim();
    if (id === STAY_PAID_ID) {
      return id;
    }
  }
  return "";
}

/**
 * @param {Error} error
 * @param {Object=} ctx
 * @return {HttpsError}
 */
function asHttps(error, ctx) {
  if (error instanceof HttpsError) {
    return error;
  }
  if (error && error.code === "failed-precondition") {
    return new HttpsError(
        "failed-precondition",
        (error && error.message) || ROOM_TYPE_SOLD_OUT,
    );
  }
  console.error("[createStayBooking] unexpected", {
    action: ctx && ctx.action || "createStayBooking",
    shopId: ctx && ctx.shopId || "",
    bookingId: ctx && ctx.bookingId || "",
    requestId: ctx && ctx.requestId || "",
    message: error && error.message ? error.message : String(error),
    stack: error && error.stack,
  });
  return new HttpsError("internal", "系統忙碌，請稍後再試");
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<void>}
 */
async function assertPhysicalRoomFree(transaction, firestore, params) {
  const shopId = normalizeString(params.shopId);
  const roomId = normalizeString(params.roomId);
  const excludeBookingId = normalizeString(params.excludeBookingId);
  const nights = Array.isArray(params.dateKeys) && params.dateKeys.length > 0 ?
    params.dateKeys : stayNightKeys(params.startDate, params.endDate);
  const roomRef = firestore.collection("shops").doc(shopId)
      .collection("rooms").doc(roomId);
  const roomSnap = await transaction.get(roomRef);
  if (!roomSnap.exists) {
    throw new HttpsError("failed-precondition", "找不到房間");
  }
  const room = {id: roomId, ...(roomSnap.data() || {})};
  if (roomPermanentlyUnsellable(room)) {
    throw new HttpsError("failed-precondition", "此房間目前不可賣");
  }
  for (const dateKey of nights) {
    const calRef = firestore.collection("shops").doc(shopId)
        .collection("room_calendar").doc(`${roomId}_${dateKey}`);
    const calSnap = await transaction.get(calRef);
    if (!calSnap.exists) {
      continue;
    }
    const calendar = calSnap.data() || {};
    const status = normalizeString(calendar.status);
    const owner = normalizeString(calendar.bookingId);
    if (isManualCalendarStatus(status)) {
      throw new HttpsError(
          "failed-precondition",
          "此房間在該日期已被手動關閉或維修",
      );
    }
    if (owner && owner === excludeBookingId) {
      continue;
    }
    if (calendarBlocksRoom(status)) {
      const message = status === CHECKOUT_CLEANING_STATUS ?
        "此房間退房後待清潔，該日不可安排" :
        "此房間在該日期區間已被預約";
      throw new HttpsError("failed-precondition", message);
    }
  }
  const bookingsSnap = await transaction.get(
      firestore.collection("bookings")
          .where("shopId", "==", shopId)
          .where("status", "in", ["pending", "confirmed", "checked_in"]),
  );
  const occupanciesSnap = await transaction.get(
      firestore.collection("shops").doc(shopId)
          .collection("room_occupancies").where("status", "==", "active"),
  );
  const startDate = params.startDate;
  const endDate = params.endDate;
  const occupied = remainingRoomsFromData({
    rooms: [room],
    bookings: bookingsSnap.docs.map((doc) => {
      return {id: doc.id, ...(doc.data() || {})};
    }).filter((item) => normalizeString(item.roomId) === roomId),
    occupancies: occupanciesSnap.docs.map((doc) => doc.data() || {})
        .filter((item) => normalizeString(item.roomId) === roomId),
    calendarEntries: [],
    holdEntries: [],
    roomTypeId: normalizeString(room.roomTypeId),
    startAt: startDate,
    endAt: endDate,
    excludeBookingId,
    dateKey: stayNightKeys(startDate, endDate)[0] || "",
  });
  if (occupied.freeCount <= 0) {
    throw new HttpsError("failed-precondition", "此房間在該日期區間已被預約");
  }
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} roomId
 * @param {Array<string>} nights
 * @param {string} bookingId
 * @param {string} status
 * @return {void}
 */
function writeStayCalendar(
    transaction, firestore, shopId, roomId, nights, bookingId, status,
) {
  nights.forEach((dateKey) => {
    const calRef = firestore.collection("shops").doc(shopId)
        .collection("room_calendar").doc(`${roomId}_${dateKey}`);
    transaction.set(calRef, {
      roomId,
      date: dateKey,
      status,
      bookingId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} roomId
 * @param {string} dateKey
 * @return {FirebaseFirestore.DocumentReference}
 */
function calendarDocRef(firestore, shopId, roomId, dateKey) {
  return firestore.collection("shops").doc(shopId)
      .collection("room_calendar").doc(`${roomId}_${dateKey}`);
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} roomId
 * @param {Array<string>} dateKeys
 * @return {Promise<Array<Object>>}
 */
async function readCalendarDocs(
    transaction, firestore, shopId, roomId, dateKeys,
) {
  const reads = [];
  for (let i = 0; i < dateKeys.length; i += 1) {
    const dateKey = dateKeys[i];
    const ref = calendarDocRef(firestore, shopId, roomId, dateKey);
    const snap = await transaction.get(ref);
    reads.push({ref, snap, dateKey});
  }
  return reads;
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Array<Object>} reads
 * @param {string} bookingId
 * @return {void}
 */
function deleteOwnedCalendarDocs(transaction, reads, bookingId) {
  reads.forEach((item) => {
    if (!item.snap.exists) {
      return;
    }
    if (canReleaseOwnedCalendar(item.snap.data() || {}, bookingId)) {
      transaction.delete(item.ref);
    }
  });
}

/**
 * 客戶指定的活動由後端重算。沒有活動時清掉客戶自填折扣。
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} input
 * @return {Promise<Object|null>}
 */
async function resolveStayCampaign(firestore, input) {
  const booking = input.booking || {};
  const campaignId = normalizeString(booking.discountCampaignId);
  const clientDiscount = toInt(booking.discountAmount, 0);
  if (!campaignId) {
    booking.discountAmount = 0;
    booking.discountCampaignId = "";
    booking.discountCampaignName = "";
    booking.discountUsedNights = 0;
    booking.discountValue = 0;
    booking.discountBase = 0;
    booking.totalPrice = Math.max(0, toInt(booking.totalPrice, 0) +
      clientDiscount);
    return null;
  }
  const snap = await firestore.collection("shops").doc(input.shopId)
      .collection("discount_campaigns").doc(campaignId).get();
  if (!snap.exists) {
    throw new HttpsError("failed-precondition", "找不到優惠活動");
  }
  const data = snap.data() || {};
  const campaign = {
    id: snap.id,
    ...data,
    startAt: toDate(data.startAt),
    endAt: toDate(data.endAt),
    stayStartAt: toDate(data.stayStartAt),
    stayEndAt: toDate(data.stayEndAt),
    createdAt: toDate(data.createdAt) || new Date(0),
    usedCount: await readCampaignUsedCount(
        firestore, input.shopId, snap.id,
    ),
  };
  if (toInt(booking.couponDiscountAmount, 0) > 0 &&
      campaign.allowCouponTogether !== true) {
    throw new HttpsError("failed-precondition", "此優惠活動不可與優惠券併用");
  }
  const memberCampaignUsage = {};
  const memberCampaignUsedNights = {};
  let isFirstBooking = true;
  let memberJoinedAt = null;
  if (input.userId) {
    const usedSnap = await firestore.collection("bookings")
        .where("shopId", "==", input.shopId)
        .where("userId", "==", input.userId).get();
    usedSnap.docs.forEach((doc) => {
      const row = doc.data() || {};
      const status = normalizeString(row.status);
      const valid = status === "pending" || status === "confirmed" ||
        status === "checked_in" || status === "completed";
      if (!valid) {
        return;
      }
      isFirstBooking = false;
      const cid = normalizeString(row.discountCampaignId);
      if (!cid) {
        return;
      }
      memberCampaignUsage[cid] = (memberCampaignUsage[cid] || 0) + 1;
      memberCampaignUsedNights[cid] =
        (memberCampaignUsedNights[cid] || 0) + toInt(row.discountUsedNights, 0);
    });
    const memberSnap = await firestore.collection("shops").doc(input.shopId)
        .collection("members").doc(input.userId).get();
    memberJoinedAt = toDate((memberSnap.data() || {}).createdAt);
  }
  const quote = quoteAccommodationCampaign(campaign, {
    checkInDate: input.startDate,
    checkOutDate: input.endDate,
    roomTypeId: input.roomTypeId,
    roomAmount: toInt(booking.roomSubtotal, 0),
    petAmount: toInt(booking.extraPetTotal, 0),
    extraServiceAmount: 0,
    isFirstBooking,
    memberJoinedAt,
    memberCampaignUsage,
    memberCampaignUsedNights,
    hasVerifiedGoogleReview: false,
  }, new Date());
  if (!quote) {
    throw new HttpsError("failed-precondition", "此優惠活動目前無法使用");
  }
  const serverDiscount = toInt(quote.discountAmount, 0);
  booking.totalPrice = Math.max(0, toInt(booking.totalPrice, 0) +
    clientDiscount - serverDiscount);
  booking.discountAmount = serverDiscount;
  booking.discountCampaignId = campaign.id;
  booking.discountCampaignName = normalizeString(campaign.name);
  booking.discountCampaignType = normalizeString(campaign.type);
  booking.discountValueType = normalizeString(campaign.valueType);
  booking.discountValue = campaign.discountValue || 0;
  booking.discountUsedNights = quote.discountUsedNights || 0;
  booking.discountBase = quote.discountBaseAmount || 0;
  booking.allowCouponTogether = campaign.allowCouponTogether === true;
  return campaign;
}

exports.createStayBooking = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const roomTypeId = normalizeString(data.roomTypeId);
      const startDate = toDate(data.startDate);
      const endDate = toDate(data.endDate);
      const uid = request.auth.uid;
      if (!shopId || !roomTypeId || !startDate || !endDate) {
        throw new HttpsError("invalid-argument", "缺少住宿房型或日期");
      }
      const isStaff = await hasShopPermission(
          shopId, uid, "manage_bookings",
      ) || isRootAdmin(uid);
      const source = isStaff && normalizeString(data.source) === "admin" ?
        "admin" : "customer";
      const userId = source === "admin" ?
        normalizeString(data.userId) : uid;
      if (!userId) {
        throw new HttpsError("invalid-argument", "缺少會員");
      }
      if (source === "customer" && normalizeString(data.userId) &&
          normalizeString(data.userId) !== uid) {
        throw new HttpsError("permission-denied", "沒有權限代訂");
      }
      const requestId = normalizeString(data.requestId);
      const firestore = admin.firestore();
      const bookingRef = requestId ?
        firestore.collection("bookings").doc(requestId) :
        firestore.collection("bookings").doc();
      const existing = await bookingRef.get();
      if (existing.exists) {
        const existingData = existing.data() || {};
        if (normalizeString(existingData.shopId) !== shopId) {
          throw new HttpsError("permission-denied", "沒有權限使用此訂單");
        }
        if (!isStaff && normalizeString(existingData.userId) !== uid) {
          throw new HttpsError("permission-denied", "沒有權限使用此訂單");
        }
        return {bookingId: bookingRef.id, reused: true};
      }
      const booking = data.booking && typeof data.booking === "object" ?
        data.booking : {};
      const stayCampaign = await resolveStayCampaign(firestore, {
        shopId,
        userId,
        roomTypeId,
        startDate,
        endDate,
        booking,
      });
      const pointSettingSnap = await firestore.collection("shops").doc(shopId)
          .collection("settings").doc("points").get();
      const pointSetting = pointSettingSnap.data() || {};
      const memberState = await loadAppMemberState(firestore, shopId, userId);
      const shopSnap = await firestore.collection("shops").doc(shopId).get();
      const shopData = shopSnap.data() || {};
      let stayCareEntitlement = {};
      let stayCareAddons = Array.isArray(booking.addons) ? booking.addons : [];
      let stayPayableAfterCoupon = Math.max(0, toInt(booking.totalPrice, 0));
      try {
        const quotedCare = resolveDailyCareEntitlement({
          setting: shopData.dailyCareSetting || {},
          isDaycare: false,
          shopDaycareOn: true,
          offerId: roomTypeId,
          offerName: normalizeString(booking.roomTypeName),
          addonId: requestedStayCareAddonId(booking, data),
          startDate,
          endDate,
          nights: toInt(booking.nights, 1),
        });
        const adjusted = applyAuthoritativeCare({
          addons: booking.addons,
          payableAfterCoupon: toInt(booking.totalPrice, 0),
          quoted: quotedCare,
        });
        stayCareEntitlement = adjusted.entitlement;
        stayCareAddons = adjusted.addons;
        stayPayableAfterCoupon = adjusted.payableAfterCoupon;
      } catch (error) {
        throw new HttpsError(
            "failed-precondition",
            error && error.message ? error.message : "照護回報無法使用",
        );
      }
      try {
        await firestore.runTransaction(async (transaction) => {
          const again = await transaction.get(bookingRef);
          if (again.exists) {
            return;
          }
          const shopInTx = await transaction.get(
              firestore.collection("shops").doc(shopId),
          );
          const stayAutoCleaning = newStayAutoCleaningSnapshot(
              shopInTx.data() || {},
          );
          const states = await loadStayRoomTypeHoldStates(
              transaction, firestore, {
                shopId,
                roomTypeId,
                startDate,
                endDate,
                bookingId: bookingRef.id,
                autoCleaning: stayAutoCleaning,
              },
          );
          const payableAfterCoupon = stayPayableAfterCoupon;
          let campaignPlan = null;
          if (stayCampaign) {
            const freshCampaign = await readCampaignForUse(
                transaction,
                firestore,
                shopId,
                stayCampaign.id,
                new Date(),
            );
            campaignPlan = await readCampaignUsageReserve(
                transaction, firestore, {
                  shopId,
                  campaignId: freshCampaign.id,
                  bookingId: bookingRef.id,
                  limit: freshCampaign.totalUsageLimit,
                },
            );
          }
          const spendPlan = await prepareSpendDeduct(transaction, {
            firestore,
            shopId,
            userId,
            bookingId: bookingRef.id,
            setting: pointSetting,
            channel: "stay",
            isAppMember: memberState.isAppMember,
            requestedPoints: toInt(
                data.requestedPoints != null ?
                  data.requestedPoints : booking.requestedPoints, 0,
            ),
            payableAfterCoupon,
            operatorUid: uid,
          });
          const bookingCode = await generateBookingCode(transaction, shopId);
          commitCampaignUsageReserve(transaction, firestore, campaignPlan);
          commitSpendDeduct(transaction, spendPlan);
          states.forEach((state) => commitRoomTypeHold(transaction, state));
          const depositExpireAt = toDate(booking.depositExpireAt);
          const pointAmount = spendPlan.pointAmount || 0;
          const pointsUsed = spendPlan.pointsUsed || 0;
          const totalPrice = Math.max(0, payableAfterCoupon - pointAmount);
          let depositAmount = toInt(booking.depositAmount, 0);
          if (depositAmount < 0) {
            depositAmount = 0;
          }
          if (depositAmount > totalPrice) {
            depositAmount = totalPrice;
          }
          const expectedRewardPoints = computeEarnPoints(pointSetting, {
            ...booking,
            nights: toInt(booking.nights, stayNightKeys(startDate, endDate)
                .length),
            totalPrice,
            paidAmount: 0,
            pointAmount,
          }, {isAppMember: memberState.isAppMember, preview: true});
          transaction.set(bookingRef, {
            ...booking,
            autoCleaningAfterCheckout: stayAutoCleaning,
            requestId: requestId || bookingRef.id,
            bookingId: bookingRef.id,
            bookingCode,
            shopId,
            userId,
            source,
            roomTypeId,
            addons: stayCareAddons,
            dailyCareEntitlement: stayCareEntitlement,
            roomId: null,
            roomName: null,
            assignStatus: "unassigned",
            bookingKind: BOOKING_KIND_ACCOMMODATION,
            startDate: admin.firestore.Timestamp.fromDate(startDate),
            endDate: admin.firestore.Timestamp.fromDate(endDate),
            nights: toInt(booking.nights, stayNightKeys(startDate, endDate)
                .length),
            totalPrice,
            remainingAmount: totalPrice,
            depositAmount,
            pointAmount,
            pointsUsed,
            pointsDiscountAmount: pointAmount,
            expectedRewardPoints,
            rewardPointsSystem: expectedRewardPoints,
            status: "pending",
            depositExpireAt: depositExpireAt ?
              admin.firestore.Timestamp.fromDate(depositExpireAt) : null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...bookingSearchFields({
              customerName: booking.customerName,
              customerPhone: booking.customerPhone,
              bookingCode,
              pets: booking.pets,
            }),
            ...(booking.customFormAnswers ? {
              customFormAnswers: stampSubmittedAt(
                  booking.customFormAnswers,
                  admin.firestore.FieldValue,
              ),
            } : {}),
            ...(booking.adminCustomFormAnswers ? {
              adminCustomFormAnswers: stampSubmittedAt(
                  booking.adminCustomFormAnswers,
                  admin.firestore.FieldValue,
              ),
            } : {}),
            ...(booking.petFormAnswersByPetId ? {
              petFormAnswersByPetId: stampSubmittedAt(
                  booking.petFormAnswersByPetId,
                  admin.firestore.FieldValue,
              ),
            } : {}),
            ...(booking.adminPetFormAnswersByPetId ? {
              adminPetFormAnswersByPetId: stampSubmittedAt(
                  booking.adminPetFormAnswersByPetId,
                  admin.firestore.FieldValue,
              ),
            } : {}),
          });
        });
      } catch (error) {
        throw asHttps(error, {
          action: "createStayBooking",
          shopId,
          bookingId: bookingRef.id,
          requestId,
        });
      }
      return {bookingId: bookingRef.id, reused: false};
    },
);

exports.manageStayInventory = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const action = normalizeString(data.action);
      const uid = request.auth.uid;
      if (!shopId || !bookingId || !action) {
        throw new HttpsError("invalid-argument", "缺少住宿庫存操作資料");
      }
      const isStaff = await hasShopPermission(
          shopId, uid, "manage_bookings",
      ) || isRootAdmin(uid);
      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      const bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "找不到這筆訂單");
      }
      const booking = {id: bookingId, ...(bookingSnap.data() || {})};
      if (normalizeString(booking.shopId) !== shopId) {
        throw new HttpsError("permission-denied", "沒有權限操作此訂單");
      }
      const isOwner = normalizeString(booking.userId) === uid;
      if (!isStaff && !isOwner) {
        throw new HttpsError("permission-denied", "沒有權限操作此訂單");
      }
      const startDate = toDate(booking.startDate);
      const endDate = toDate(booking.endDate);
      try {
        if (action === "release") {
          await firestore.runTransaction(async (transaction) => {
            await transaction.get(bookingRef);
            await releaseStayRoomTypeHoldsInTransaction(
                transaction, firestore, booking,
            );
          });
          return {ok: true, action};
        }
        if (action === "releaseCalendar") {
          await firestore.runTransaction(async (transaction) => {
            const live = await transaction.get(bookingRef);
            const liveData = live.data() || {};
            const assignedRoomId = normalizeString(liveData.roomId);
            if (!assignedRoomId) {
              return;
            }
            const reads = await readCalendarDocs(
                transaction,
                firestore,
                shopId,
                assignedRoomId,
                stayReleaseDateKeys(liveData.startDate, liveData.endDate),
            );
            deleteOwnedCalendarDocs(transaction, reads, bookingId);
          });
          return {ok: true, action};
        }
        if (!isStaff) {
          throw new HttpsError("permission-denied", "沒有權限分房");
        }
        if (action === "assign" || action === "change") {
          const roomId = normalizeString(data.roomId);
          const roomName = normalizeString(data.roomName) || roomId;
          if (!roomId) {
            throw new HttpsError("invalid-argument", "請選擇房間");
          }
          const reason = normalizeString(data.reason);
          const liveBefore = bookingSnap.data() || {};
          const fromRoomId = normalizeString(liveBefore.roomId);
          if (action === "change" || (fromRoomId && fromRoomId !== roomId)) {
            if (!reason) {
              throw new HttpsError("invalid-argument", "更換房間請填寫原因");
            }
          }
          const operator = await resolveOperatorIdentity({
            operatorUid: uid,
            operatorEmail: normalizeString(
                request.auth.token && request.auth.token.email,
            ),
            shopId,
          });
          await firestore.runTransaction(async (transaction) => {
            const live = await transaction.get(bookingRef);
            const liveData = live.data() || {};
            const oldRoomId = normalizeString(liveData.roomId);
            const oldReads = oldRoomId ?
              await readCalendarDocs(
                  transaction,
                  firestore,
                  shopId,
                  oldRoomId,
                  stayReleaseDateKeys(startDate, endDate),
              ) : [];
            const autoCleaning = stayAutoCleaningForRebuild(
                {...liveData, id: bookingId},
                oldReads,
            );
            const plan = stayCalendarPlan(startDate, endDate, autoCleaning);
            await assertPhysicalRoomFree(transaction, firestore, {
              shopId,
              roomId,
              startDate,
              endDate,
              excludeBookingId: bookingId,
              dateKeys: plan.blockedKeys,
            });
            // 所有讀取先完成。房型保留的讀寫包在釋放函式內，
            // 必須放在刪除舊日曆、寫入新日曆之前。
            await releaseStayRoomTypeHoldsInTransaction(
                transaction,
                firestore,
                {
                  ...liveData,
                  id: bookingId,
                  shopId,
                },
            );
            if (oldRoomId) {
              deleteOwnedCalendarDocs(transaction, oldReads, bookingId);
            }
            writeStayCalendar(
                transaction,
                firestore,
                shopId,
                roomId,
                plan.nights,
                bookingId,
                "booked",
            );
            if (plan.checkoutKey) {
              writeStayCalendar(
                  transaction,
                  firestore,
                  shopId,
                  roomId,
                  [plan.checkoutKey],
                  bookingId,
                  CHECKOUT_CLEANING_STATUS,
              );
            }
            const roomTypeName = normalizeString(liveData.roomTypeName) ||
              normalizeString(liveData.roomTypeNameSnapshot);
            transaction.update(bookingRef, {
              roomId,
              roomName,
              assignStatus: "assigned",
              assignedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            const changing = Boolean(oldRoomId && oldRoomId !== roomId);
            writeActionLogInTransaction(transaction, {
              shopId,
              targetId: bookingId,
              bookingId,
              bookingKind: BOOKING_KIND_ACCOMMODATION,
              action: changing ? "stay_change_room" : "stay_assign_room",
              type: changing ? "room_changed" : "room_assigned",
              operatorUid: uid,
              operatorEmail: operator.email,
              operatorDisplayName: operator.displayName,
              operatorRole: "staff",
              payload: {
                roomTypeName,
                fromRoomTypeName: roomTypeName,
                toRoomTypeName: roomTypeName,
                fromRoomId: oldRoomId,
                fromRoomName: normalizeString(liveData.roomName) || oldRoomId,
                toRoomId: roomId,
                toRoomName: roomName,
                oldRoomId,
                oldRoomName: normalizeString(liveData.roomName) || oldRoomId,
                newRoomId: roomId,
                newRoomName: roomName,
                roomId,
                roomName,
                reason,
              },
            }, operator);
          });
          return {ok: true, action};
        }
        if (action === "changeDates" || action === "unassign") {
          const nextStart = action === "changeDates" ?
            (toDate(data.startDate) || startDate) : startDate;
          const nextEnd = action === "changeDates" ?
            (toDate(data.endDate) || endDate) : endDate;
          if (!nextStart || !nextEnd ||
              stayNightKeys(nextStart, nextEnd).length === 0) {
            throw new HttpsError("invalid-argument", "住宿日期不正確");
          }
          await firestore.runTransaction(async (transaction) => {
            const live = await transaction.get(bookingRef);
            const liveData = live.data() || {};
            const assignedRoomId = normalizeString(liveData.roomId);
            const oldReads = assignedRoomId ? await readCalendarDocs(
                transaction,
                firestore,
                shopId,
                assignedRoomId,
                stayReleaseDateKeys(liveData.startDate, liveData.endDate),
            ) : [];
            const autoCleaning = stayAutoCleaningForRebuild(
                {...liveData, id: bookingId},
                oldReads,
            );
            const nextPlan = stayCalendarPlan(
                nextStart, nextEnd, autoCleaning,
            );
            let holdStates = [];
            if (action === "unassign" || !assignedRoomId) {
              holdStates = await loadStayRoomTypeHoldStates(
                  transaction, firestore, {
                    shopId,
                    roomTypeId: normalizeString(
                        liveData.requestedRoomTypeId || liveData.roomTypeId,
                    ),
                    startDate: nextStart,
                    endDate: nextEnd,
                    bookingId,
                    autoCleaning,
                  },
              );
            } else {
              await assertPhysicalRoomFree(transaction, firestore, {
                shopId,
                roomId: assignedRoomId,
                startDate: nextStart,
                endDate: nextEnd,
                excludeBookingId: bookingId,
                dateKeys: nextPlan.blockedKeys,
              });
            }
            await releaseStayRoomTypeHoldsInTransaction(
                transaction, firestore, {
                  ...liveData,
                  id: bookingId,
                  shopId,
                },
            );
            if (assignedRoomId) {
              deleteOwnedCalendarDocs(transaction, oldReads, bookingId);
            }
            if (action === "unassign" || !assignedRoomId) {
              holdStates.forEach((state) => {
                commitRoomTypeHold(transaction, state);
              });
            } else {
              writeStayCalendar(
                  transaction, firestore, shopId, assignedRoomId,
                  nextPlan.nights, bookingId, "booked",
              );
              if (nextPlan.checkoutKey) {
                writeStayCalendar(
                    transaction, firestore, shopId, assignedRoomId,
                    [nextPlan.checkoutKey], bookingId,
                    CHECKOUT_CLEANING_STATUS,
                );
              }
            }
            const bookingUpdate = {
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (action === "changeDates") {
              bookingUpdate.startDate =
                admin.firestore.Timestamp.fromDate(nextStart);
              bookingUpdate.endDate =
                admin.firestore.Timestamp.fromDate(nextEnd);
              bookingUpdate.nights = nextPlan.nights.length;
            }
            if (action === "unassign") {
              bookingUpdate.roomId = null;
              bookingUpdate.roomName = null;
              bookingUpdate.assignStatus = "unassigned";
            }
            transaction.update(bookingRef, bookingUpdate);
          });
          return {
            ok: true,
            action,
            nights: stayNightKeys(nextStart, nextEnd).length,
          };
        }
        throw new HttpsError("invalid-argument", "不支援的住宿庫存操作");
      } catch (error) {
        throw asHttps(error, {
          action: action || "manageStayInventory",
          shopId,
          bookingId,
          requestId: normalizeString(data.requestId),
        });
      }
    },
);
