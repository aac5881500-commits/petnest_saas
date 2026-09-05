// 檔案名稱：functions/daycare/convert_daycare_to_accommodation.js
// 功能說明：臨托轉住宿：新開住宿單並互相連結，不覆蓋原臨托服務種類

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  BOOKING_KIND_ACCOMMODATION,
  BOOKING_KIND_DAYCARE,
  generateBookingCode,
  hasShopPermission,
  normalizeString,
  resolveBookingKind,
  toDate,
  toInt,
  summarizePolicyForService,
  writeActionLog,
} = require("./daycare_utils");
const {
  loadActiveOccupancies,
  releaseOccupancyDocs,
} = require("./daycare_occupancy");

const POLICIES = [
  "keep_daycare",
  "credit_all",
  "custom",
  "cancel_daycare_fee",
];

/**
 * @param {string} policy
 * @param {number} daycareTotal
 * @param {number} customAmount
 * @return {number}
 */
function conversionCredit(policy, daycareTotal, customAmount) {
  if (policy === "credit_all" || policy === "cancel_daycare_fee") {
    return Math.max(0, daycareTotal);
  }
  if (policy === "custom") {
    return Math.max(0, Math.min(daycareTotal, customAmount));
  }
  return 0;
}

exports.convertDaycareToAccommodation = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const requestId = normalizeString(data.requestId);
      if (!shopId || !bookingId) {
        throw new HttpsError("invalid-argument", "缺少訂單資料");
      }
      const allowed = await hasShopPermission(
          shopId, uid, "convert_daycare_to_accommodation",
      );
      if (!allowed) {
        throw new HttpsError("permission-denied", "沒有轉住宿權限");
      }

      const policy = POLICIES.includes(normalizeString(data.conversionPolicy)) ?
        normalizeString(data.conversionPolicy) : "keep_daycare";
      const firestore = admin.firestore();

      if (requestId) {
        const opSnap = await firestore.collection("shops").doc(shopId)
            .collection("daycare_ops").doc(requestId).get();
        if (opSnap.exists) {
          return opSnap.data();
        }
      }

      const daycareRef = firestore.collection("bookings").doc(bookingId);
      const daycareSnap = await daycareRef.get();
      if (!daycareSnap.exists) {
        throw new HttpsError("not-found", "找不到臨托訂單");
      }
      const daycare = daycareSnap.data() || {};
      if (resolveBookingKind(daycare) !== BOOKING_KIND_DAYCARE) {
        throw new HttpsError("failed-precondition", "僅臨托訂單可轉住宿");
      }
      if (normalizeString(daycare.shopId) !== shopId) {
        throw new HttpsError("permission-denied", "訂單不屬於此店家");
      }
      if (daycare.convertedToAccommodation === true &&
          normalizeString(daycare.convertedBookingId)) {
        return {
          ok: true,
          reused: true,
          stayBookingId: daycare.convertedBookingId,
        };
      }
      if (["cancelled"].includes(daycare.status)) {
        throw new HttpsError("failed-precondition", "已取消的臨托不可轉住宿");
      }

      const stayStart = toDate(data.startDate);
      const stayEnd = toDate(data.endDate);
      if (!stayStart || !stayEnd || stayEnd <= stayStart) {
        throw new HttpsError("invalid-argument", "請選擇正確的入住與退房日");
      }
      const nights = toInt(data.nights, 1);
      const stayTotal = Math.max(0, toInt(data.stayTotalPrice, 0));
      const roomTypeId = normalizeString(data.roomTypeId);
      const roomId = normalizeString(data.roomId);
      if (!roomTypeId) {
        throw new HttpsError("invalid-argument", "請選擇住宿房型");
      }

      const policySnap = await firestore.collection("shops").doc(shopId)
          .collection("policies").doc("checkin_policy").get();
      const stayPolicy = summarizePolicyForService(
          policySnap.data() || null, "accommodation",
      );
      const accommodationSignMethod =
        normalizeString(data.accommodationPolicySignMethod);
      if (stayPolicy.required) {
        if (!["member_online", "staff_witness", "paper"].includes(
            accommodationSignMethod,
        )) {
          throw new HttpsError(
              "failed-precondition",
              "轉住宿前請完成住宿條款簽署或記錄現場簽署",
          );
        }
        if (accommodationSignMethod === "member_online") {
          const userId = normalizeString(daycare.userId);
          const acc = await firestore.collection("users").doc(userId)
              .collection("policy_acceptances").doc(shopId).get();
          const byService = (acc.data() || {}).acceptedVersions || {};
          const acceptedStay = toInt(
              byService.accommodation,
              toInt((acc.data() || {}).acceptedVersion, 0),
          );
          if (acceptedStay !== stayPolicy.version) {
            throw new HttpsError(
                "failed-precondition",
                "客戶尚未同意目前住宿條款，請補簽後再轉住宿",
            );
          }
        }
      }

      const daycareTotal = toInt(daycare.totalPrice, 0);
      const daycarePaid = toInt(daycare.paidAmount, 0);
      const credit = conversionCredit(
          policy, daycareTotal, toInt(data.conversionCreditAmount, 0),
      );
      const stayPayable = Math.max(0, stayTotal - credit);
      const transferredPaid = Math.min(daycarePaid, stayPayable);
      const stayRemaining = Math.max(0, stayPayable - transferredPaid);
      const daycareRefundPending = policy === "cancel_daycare_fee" ?
        Math.max(0, daycarePaid - transferredPaid) :
        Math.max(0, daycarePaid - credit);

      const stayRef = firestore.collection("bookings").doc();
      const occupancySnap = await loadActiveOccupancies(
          firestore, shopId, bookingId,
      );

      await firestore.runTransaction(async (transaction) => {
        for (const doc of occupancySnap.docs) {
          await transaction.get(doc.ref);
        }
        const latest = await transaction.get(daycareRef);
        const latestData = latest.data() || {};
        if (latestData.convertedToAccommodation === true &&
            normalizeString(latestData.convertedBookingId)) {
          return;
        }
        const bookingCode = await generateBookingCode(transaction, shopId);
        transaction.set(stayRef, {
          bookingId: stayRef.id,
          bookingCode,
          bookingKind: BOOKING_KIND_ACCOMMODATION,
          shopId,
          shopName: daycare.shopName || "",
          userId: daycare.userId,
          source: "admin",
          customerName: daycare.customerName || "",
          customerPhone: daycare.customerPhone || "",
          petIds: daycare.petIds || [],
          pets: daycare.pets || [],
          serviceType: normalizeString(data.serviceType) || "cat_hotel",
          startDate: admin.firestore.Timestamp.fromDate(stayStart),
          endDate: admin.firestore.Timestamp.fromDate(stayEnd),
          nights,
          roomTypeId,
          roomTypeName: normalizeString(data.roomTypeName),
          roomId: roomId || null,
          roomName: normalizeString(data.roomName) || null,
          assignStatus: roomId ? "assigned" : "unassigned",
          status: "confirmed",
          totalPrice: stayTotal,
          originalTotal: stayTotal,
          paidAmount: transferredPaid,
          remainingAmount: stayRemaining,
          paymentStatus: stayRemaining <= 0 && stayPayable > 0 ?
            "paid" : (transferredPaid > 0 ? "partial" : "unpaid"),
          conversionCreditAmount: credit,
          convertedFromDaycareBookingId: bookingId,
          conversionPolicy: policy,
          policyId: "checkin_policy",
          policyKind: "accommodation",
          policyServiceType: "accommodation",
          policyVersion: stayPolicy.required ? stayPolicy.version : 0,
          policyVersionId: stayPolicy.required ?
            `v${stayPolicy.version}` : "",
          policyTitle: stayPolicy.title || "入住須知",
          policySignMethod: stayPolicy.required ?
            accommodationSignMethod : "",
          policySignedByUid: uid,
          policyAcceptedAt: stayPolicy.required ?
            admin.firestore.FieldValue.serverTimestamp() : null,
          accommodationPolicySignMethod: stayPolicy.required ?
            accommodationSignMethod : "",
          note: `由臨托 ${daycare.bookingCode || bookingId} 轉入`,
          addons: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const daycareUpdates = {
          convertedToAccommodation: true,
          convertedBookingId: stayRef.id,
          conversionPolicy: policy,
          conversionCreditAmount: credit,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (policy === "cancel_daycare_fee") {
          daycareUpdates.status = "completed";
          daycareUpdates.completedAt =
            admin.firestore.FieldValue.serverTimestamp();
          daycareUpdates.refundStatus = daycareRefundPending > 0 ?
            "pending_manual" : "";
          daycareUpdates.refundAmount = daycareRefundPending;
        } else if (daycare.status === "checked_in") {
          daycareUpdates.status = "completed";
          daycareUpdates.completedAt =
            admin.firestore.FieldValue.serverTimestamp();
        }
        transaction.update(daycareRef, daycareUpdates);
        releaseOccupancyDocs(transaction, occupancySnap.docs);
      });

      const result = {
        ok: true,
        stayBookingId: stayRef.id,
        conversionCreditAmount: credit,
        stayPayable,
        stayRemaining,
        daycareRefundPending,
        conversionPolicy: policy,
      };
      if (requestId) {
        await firestore.collection("shops").doc(shopId)
            .collection("daycare_ops").doc(requestId).set(result);
      }
      await writeActionLog({
        shopId,
        targetId: bookingId,
        action: "daycare_convert_to_accommodation",
        operatorUid: uid,
        operatorRole: "staff",
        payload: {
          ...result,
          accommodationPolicySignMethod: stayPolicy.required ?
            accommodationSignMethod : "",
          accommodationPolicyVersion: stayPolicy.required ?
            stayPolicy.version : 0,
        },
      });
      return result;
    },
);

module.exports.conversionCredit = conversionCredit;
