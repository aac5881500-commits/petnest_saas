/* eslint-disable require-jsdoc */
// 檔案名稱：functions/points/sync_booking_points.js
// 功能說明：住宿／安親訂單扣點、退點、發點、重算；冪等且雙寫 currentPoints／points。

const admin = require("firebase-admin");
const {HttpsError} = require("firebase-functions/v2/https");
const {normalizeString, toInt} = require("../daycare/daycare_utils");
const {
  pointsBalance,
  canSpend,
  capSpend,
  canIssueEarn,
  computeEarnPoints,
  resolveFinalEarn,
  channelOfBooking,
  isWalkInMember,
} = require("./booking_points");

function earnLogId(bookingId) {
  return `booking_${bookingId}`;
}

function spendLogId(bookingId) {
  return `spend_booking_${bookingId}`;
}

function earnStatus(eligible, cancelled, target, adjusted) {
  if (eligible) {
    if (target > 0) {
      return adjusted ? "issued_adjusted" : "issued";
    }
    return "not_eligible";
  }
  return cancelled ? "adjusted_after_cancel" : "pending";
}

function spendStoreLogId(orderId) {
  return `spend_store_${orderId}`;
}

function refsFor(firestore, shopId, userId, bookingId, extras) {
  const extra = extras || {};
  const shop = firestore.collection("shops").doc(shopId);
  return {
    pointRef: shop.collection("member_points").doc(userId),
    earnRef: shop.collection("member_point_logs").doc(earnLogId(bookingId)),
    spendRef: shop.collection("member_point_logs").doc(
        extra.spendLogId || spendLogId(bookingId),
    ),
    bookingRef: extra.extraRef ||
      firestore.collection("bookings").doc(bookingId),
  };
}

function writeBalance(transaction, pointRef, params) {
  transaction.set(pointRef, {
    shopId: params.shopId,
    userId: params.userId,
    points: params.current,
    currentPoints: params.current,
    totalEarnedPoints: params.totalEarned,
    totalUsedPoints: params.totalUsed,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(params.lastEarned ? {lastEarnedAt:
      admin.firestore.FieldValue.serverTimestamp()} : {}),
    ...(params.lastUsed ? {lastUsedAt:
      admin.firestore.FieldValue.serverTimestamp()} : {}),
  }, {merge: true});
}

async function isAuthUser(userId) {
  if (!userId) {
    return false;
  }
  try {
    await admin.auth().getUser(userId);
    return true;
  } catch (error) {
    return false;
  }
}

async function loadAppMemberState(firestore, shopId, userId) {
  const authUser = await isAuthUser(userId);
  let member = null;
  try {
    const snap = await firestore.collection("shops").doc(shopId)
        .collection("members").doc(userId).get();
    member = snap.exists ? snap.data() : null;
  } catch (error) {
    member = null;
  }
  const walkIn = isWalkInMember(member, authUser);
  return {isAppMember: !walkIn, member};
}

/**
 * 建單 transaction：只讀折抵狀態。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function prepareSpendDeduct(transaction, params) {
  const empty = {pointAmount: 0, pointsUsed: 0, skip: true};
  if (!params.userId || !params.isAppMember ||
      !canSpend(params.setting || {}, params.channel)) {
    return empty;
  }
  const {pointRef, spendRef} = refsFor(
      params.firestore, params.shopId, params.userId, params.bookingId, {
        spendLogId: params.spendLogId,
        extraRef: params.extraRef,
      },
  );
  const spendSnap = await transaction.get(spendRef);
  if (spendSnap.exists) {
    const data = spendSnap.data() || {};
    if (data.returned !== true) {
      return {
        pointAmount: toInt(data.amount, 0),
        pointsUsed: Math.abs(toInt(data.points, data.pointsChange || 0)),
        skip: true,
      };
    }
    throw new HttpsError("already-exists", "此訂單點數折抵狀態異常");
  }
  const pointSnap = await transaction.get(pointRef);
  const balance = pointsBalance(pointSnap.exists ? pointSnap.data() : {});
  const capped = capSpend({
    requestedPoints: params.requestedPoints,
    balance,
    payableAfterCoupon: params.payableAfterCoupon,
    setting: params.setting,
  });
  if (capped.pointsUsed <= 0) {
    return empty;
  }
  if (balance < capped.pointsUsed) {
    throw new HttpsError("failed-precondition", "點數餘額不足");
  }
  return {
    ...capped,
    skip: false,
    shopId: params.shopId,
    userId: params.userId,
    bookingId: params.bookingId,
    operatorUid: params.operatorUid || "system",
    pointRef,
    spendRef,
    pointSnap,
    balance,
  };
}

function commitSpendDeduct(transaction, plan) {
  if (!plan || plan.skip || plan.pointsUsed <= 0) {
    return;
  }
  const current = plan.balance - plan.pointsUsed;
  const used = toInt(
      plan.pointSnap.exists && plan.pointSnap.data().totalUsedPoints, 0,
  ) + plan.pointsUsed;
  writeBalance(transaction, plan.pointRef, {
    shopId: plan.shopId,
    userId: plan.userId,
    current,
    totalEarned: toInt(
        plan.pointSnap.exists && plan.pointSnap.data().totalEarnedPoints, 0,
    ),
    totalUsed: used,
    lastUsed: true,
  });
  transaction.set(plan.spendRef, {
    shopId: plan.shopId,
    userId: plan.userId,
    bookingId: plan.bookingId,
    type: "bookingSpent",
    points: -plan.pointsUsed,
    pointsChange: -plan.pointsUsed,
    amount: plan.pointAmount,
    balanceBefore: plan.balance,
    balanceAfter: current,
    reason: "訂單折抵點數",
    operatorUid: plan.operatorUid,
    sourceId: plan.bookingId,
    returned: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function deductSpendInTransaction(transaction, params) {
  const plan = await prepareSpendDeduct(transaction, params);
  commitSpendDeduct(transaction, plan);
  return {pointAmount: plan.pointAmount || 0, pointsUsed: plan.pointsUsed || 0};
}

/**
 * 取消時退回折抵點數一次。
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 */
async function restoreSpend(firestore, params) {
  const shopId = params.shopId;
  const bookingId = params.bookingId;
  const booking = params.booking || {};
  const userId = normalizeString(booking.userId);
  if (!userId) {
    return;
  }
  const {pointRef, spendRef, bookingRef} =
    refsFor(firestore, shopId, userId, bookingId, {
      spendLogId: params.spendLogId,
      extraRef: params.extraRef,
    });
  await firestore.runTransaction(async (transaction) => {
    const spendSnap = await transaction.get(spendRef);
    if (!spendSnap.exists || spendSnap.data().returned === true) {
      return;
    }
    const spentPoints = Math.abs(toInt(
        spendSnap.data().points,
        spendSnap.data().pointsChange || toInt(booking.pointAmount, 0),
    ));
    const pointSnap = await transaction.get(pointRef);
    const balance = pointsBalance(pointSnap.exists ? pointSnap.data() : {});
    const current = balance + spentPoints;
    writeBalance(transaction, pointRef, {
      shopId,
      userId,
      current,
      totalEarned: toInt(pointSnap.exists &&
        pointSnap.data().totalEarnedPoints, 0),
      totalUsed: Math.max(0, toInt(pointSnap.exists &&
        pointSnap.data().totalUsedPoints, 0) - spentPoints),
    });
    transaction.update(spendRef, {
      returned: true,
      type: "refunded",
      returnedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.update(bookingRef, {
      pointsReturned: true,
    });
  });
}

function issuedFromEarnLog(logData) {
  if (!logData || logData.revoked === true) {
    return 0;
  }
  const change = toInt(logData.pointsChange, 0);
  if (change > 0) {
    return change;
  }
  return Math.max(0, toInt(logData.points, 0));
}

/**
 * 依目前訂單重算發點並套用差額。
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 */
async function syncEarn(firestore, params) {
  const shopId = params.shopId;
  const bookingId = params.bookingId;
  const booking = params.booking || {};
  const userId = normalizeString(booking.userId);
  if (!userId) {
    return {issued: 0};
  }
  const {isAppMember} = await loadAppMemberState(firestore, shopId, userId);
  const settingSnap = await firestore.collection("shops").doc(shopId)
      .collection("settings").doc("points").get();
  const setting = settingSnap.data() || {};
  const cancelled = String(booking.status || "").trim() === "cancelled" ||
    String(booking.status || "").trim() === "no_show";
  if (cancelled) {
    await restoreSpend(firestore, params);
  }
  const eligible = isAppMember && canIssueEarn(booking);
  const systemPoints = computeEarnPoints(setting, booking, {
    isAppMember,
    preview: !eligible,
  });
  const adjusted = booking.rewardPointsAdjusted === true;
  const target = resolveFinalEarn({
    systemPoints,
    eligible,
    adjusted,
    overridePoints: booking.rewardPointsFinal,
  });
  const {pointRef, earnRef, bookingRef} =
    refsFor(firestore, shopId, userId, bookingId);

  await firestore.runTransaction(async (transaction) => {
    const logSnap = await transaction.get(earnRef);
    const pointSnap = await transaction.get(pointRef);
    const already = issuedFromEarnLog(logSnap.exists ? logSnap.data() : null);
    const delta = target - already;
    if (delta === 0) {
      transaction.update(bookingRef, {
        rewardPointIssued: target > 0,
        rewardPointAmount: target,
        pointsIssued: target > 0,
        pointsIssuedAmount: target,
        rewardPointsSystem: systemPoints,
        pointsEarnStatus: earnStatus(eligible, cancelled, target, adjusted),
      });
      return;
    }
    const balance = pointsBalance(pointSnap.exists ? pointSnap.data() : {});
    const current = Math.max(0, balance + delta);
    writeBalance(transaction, pointRef, {
      shopId,
      userId,
      current,
      totalEarned: Math.max(0, toInt(pointSnap.exists &&
        pointSnap.data().totalEarnedPoints, 0) + delta),
      totalUsed: toInt(pointSnap.exists &&
        pointSnap.data().totalUsedPoints, 0),
      lastEarned: delta > 0,
    });
    transaction.set(earnRef, {
      shopId,
      userId,
      bookingId,
      type: delta < 0 ? "bookingAdjusted" : "bookingEarned",
      points: target,
      pointsChange: target,
      balanceBefore: balance,
      balanceAfter: current,
      reason: adjusted ? (booking.rewardPointsAdjustReason || "店員調整發點") :
        (isDaycare(booking) ? "完成安親獲得點數" : "完成住宿獲得點數"),
      operatorUid: params.operatorUid || "system",
      operatorEmail: params.operatorEmail || "",
      sourceId: bookingId,
      revoked: target <= 0,
      createdAt: logSnap.exists ? logSnap.data().createdAt :
        admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.update(bookingRef, {
      rewardPointIssued: target > 0,
      rewardPointAmount: target,
      rewardPointIssuedAt: admin.firestore.FieldValue.serverTimestamp(),
      pointsIssued: target > 0,
      pointsIssuedAmount: target,
      rewardPointsSystem: systemPoints,
      pointsEarnStatus: target > 0 ?
        (adjusted ? "issued_adjusted" : "issued") :
        (cancelled ? "adjusted_after_cancel" : "not_eligible"),
    });
  });
  return {issued: target, systemPoints};
}

function isDaycare(booking) {
  return channelOfBooking(booking) === "daycare";
}

async function syncBookingPoints(firestore, params) {
  return syncEarn(firestore, params);
}

module.exports = {
  prepareSpendDeduct,
  commitSpendDeduct,
  deductSpendInTransaction,
  restoreSpend,
  syncEarn,
  syncBookingPoints,
  loadAppMemberState,
  refsFor,
  spendLogId,
  spendStoreLogId,
  earnLogId,
};
