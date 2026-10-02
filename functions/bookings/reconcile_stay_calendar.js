// 檔案名稱：functions/bookings/reconcile_stay_calendar.js
// 功能說明：住宿房曆校正。預設 dryRun，只報告；dryRun=false 才寫單筆。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  ACTIVE_STATUSES,
  hasShopPermission,
  isRootAdmin,
  normalizeString,
} = require("../daycare/daycare_utils");
const {
  CHECKOUT_CLEANING_STATUS,
  autoCleaningAfterCheckout,
  calendarBlocksRoom,
  canReleaseOwnedCalendar,
  isManualCalendarStatus,
  stayNightKeys,
  stayReleaseDateKeys,
  taipeiDateKey,
} = require("../daycare/daycare_occupancy");

const OWNED_STATUSES = new Set([
  "booked",
  "checked_in",
  "occupied",
  CHECKOUT_CLEANING_STATUS,
]);

/**
 * 只有訂單自己存了布林值才採用。不回看店家今天的設定。
 * @param {Object} booking
 * @return {{known: boolean, value: (boolean|null)}}
 */
function bookingAutoCleaningSnapshot(booking) {
  const source = booking && typeof booking === "object" ? booking : {};
  if (source.autoCleaningAfterCheckout === true ||
    source.autoCleaningAfterCheckout === false) {
    return {known: true, value: source.autoCleaningAfterCheckout === true};
  }
  const setting = source.housekeepingSetting;
  if (setting && typeof setting === "object" &&
    (setting.autoCleaningAfterCheckout === true ||
      setting.autoCleaningAfterCheckout === false)) {
    return {
      known: true,
      value: setting.autoCleaningAfterCheckout === true,
    };
  }
  return {known: false, value: null};
}

/**
 * @param {Object} data
 * @return {boolean}
 */
function reconcileWritesAllowed(data) {
  return Boolean(data) && data.dryRun === false;
}

/**
 * @param {string} date
 * @param {string} reason
 * @param {string} status
 * @param {string} existingBookingId
 * @return {Object}
 */
function issue(date, reason, status, existingBookingId) {
  return {
    date: date || "",
    reason,
    existingStatus: status || "",
    existingBookingId: existingBookingId || "",
  };
}

/**
 * @param {Object} doc
 * @return {Object}
 */
function publicCalendar(doc) {
  return {
    date: normalizeString(doc && doc.date),
    roomId: normalizeString(doc && doc.roomId),
    bookingId: normalizeString(doc && doc.bookingId),
    status: normalizeString(doc && doc.status),
  };
}

/**
 * @param {Array<Object>} docs
 * @param {string} roomId
 * @param {string} date
 * @return {Array<Object>}
 */
function docsOnDate(docs, roomId, date) {
  return docs.filter((doc) => {
    return normalizeString(doc.date) === date &&
      normalizeString(doc.roomId) === roomId;
  });
}

/**
 * @param {Object} params
 * @return {Object}
 */
function planStayCalendarRepair(params) {
  const booking = params && params.booking ? params.booking : {};
  const bookingId = normalizeString(booking.id || booking.bookingId);
  const roomId = normalizeString(booking.roomId);
  const snapshot = bookingAutoCleaningSnapshot(booking);
  const nights = stayNightKeys(booking.startDate, booking.endDate);
  const checkoutKey = taipeiDateKey(booking.endDate);
  const expected = {};
  nights.forEach((date) => {
    expected[date] = "booked";
  });
  const checkoutKnown = snapshot.known && checkoutKey &&
    nights.indexOf(checkoutKey) < 0;
  if (checkoutKnown && snapshot.value) {
    expected[checkoutKey] = CHECKOUT_CLEANING_STATUS;
  }
  const docs = Array.isArray(params && params.calendarDocs) ?
    params.calendarDocs : [];
  const wouldCreate = [];
  const wouldDelete = [];
  const conflicts = [];
  const skipped = [];

  Object.keys(expected).sort().forEach((date) => {
    const onDate = docsOnDate(docs, roomId, date);
    const expectedStatus = expected[date];
    if (onDate.length === 0) {
      wouldCreate.push({
        date,
        roomId,
        bookingId,
        status: expectedStatus,
        action: "create",
      });
      return;
    }
    const foreign = onDate.find((doc) => {
      const owner = normalizeString(doc.bookingId);
      return owner && owner !== bookingId;
    });
    const manual = onDate.find((doc) => {
      const status = normalizeString(doc.status);
      return isManualCalendarStatus(status) || status === "cleaning";
    });
    const blocker = foreign || manual;
    if (blocker) {
      const reason = foreign ?
        "其他訂單占用，不覆蓋" :
        "人工房務狀態，不覆蓋";
      conflicts.push(issue(
          date,
          reason,
          normalizeString(blocker.status),
          normalizeString(blocker.bookingId),
      ));
      return;
    }
    const owned = onDate.find((doc) => {
      return normalizeString(doc.bookingId) === bookingId;
    });
    if (!owned) {
      conflicts.push(issue(
          date,
          "已有日曆但沒有 bookingId，不覆蓋",
          normalizeString(onDate[0].status),
          "",
      ));
      return;
    }
    const status = normalizeString(owned.status);
    const nightOk = expectedStatus === "booked" &&
      (status === "booked" ||
        status === "checked_in" ||
        status === "occupied");
    if (nightOk || status === expectedStatus) {
      return;
    }
    if (!OWNED_STATUSES.has(status)) {
      skipped.push(issue(date, "狀態無法安全改寫", status, bookingId));
      return;
    }
    wouldCreate.push({
      date,
      roomId,
      bookingId,
      status: expectedStatus,
      from: status,
      action: "update",
    });
  });

  if (!snapshot.known && checkoutKey && nights.indexOf(checkoutKey) < 0) {
    skipped.push(issue(
        checkoutKey,
        "訂單沒有退房清潔設定快照，不判斷退房日",
        "",
        "",
    ));
  }

  docs.forEach((doc) => {
    const date = normalizeString(doc.date);
    const docRoom = normalizeString(doc.roomId);
    const owner = normalizeString(doc.bookingId);
    const status = normalizeString(doc.status);
    if (!date) {
      return;
    }
    if (!docRoom) {
      skipped.push(issue(date, "沒有 roomId，不刪除", status, owner));
      return;
    }
    if (docRoom === roomId && expected[date]) {
      return;
    }
    if (!snapshot.known && docRoom === roomId && date === checkoutKey) {
      return;
    }
    if (owner !== bookingId) {
      if (!owner) {
        skipped.push(issue(date, "沒有 bookingId，不刪除", status, ""));
      } else if (docRoom === roomId) {
        conflicts.push(issue(
            date,
            "bookingId 不同，不刪除",
            status,
            owner,
        ));
      }
      return;
    }
    if (isManualCalendarStatus(status) || status === "cleaning") {
      conflicts.push(issue(date, "人工房務狀態，不刪除", status, owner));
      return;
    }
    if (!OWNED_STATUSES.has(status)) {
      skipped.push(issue(date, "狀態無法安全判定，不刪除", status, owner));
      return;
    }
    wouldDelete.push({
      date,
      roomId: docRoom,
      bookingId,
      status,
    });
  });

  const calendarIssue = wouldCreate.length > 0 ||
    wouldDelete.length > 0 ||
    conflicts.length > 0;
  let outcome = "correct";
  if (calendarIssue) {
    outcome = "incorrect";
  } else if (skipped.length > 0) {
    outcome = "skipped";
  }
  return {
    bookingId,
    roomId,
    startDate: taipeiDateKey(booking.startDate),
    endDate: taipeiDateKey(booking.endDate),
    autoCleaningAfterCheckout: snapshot.known ? snapshot.value : null,
    autoCleaningKnown: snapshot.known,
    expected,
    actual: docs
        .filter((doc) => normalizeString(doc.roomId) === roomId)
        .map(publicCalendar),
    nights,
    wouldCreate,
    wouldDelete,
    conflicts,
    skipped,
    outcome,
  };
}

/**
 * 只交出可安全執行的建立與刪除，衝突與略過不進寫入清單。
 * @param {Object} report
 * @return {{deletes: Array<Object>, sets: Array<Object>}}
 */
function repairWritePlan(report) {
  const creates = report && Array.isArray(report.wouldCreate) ?
    report.wouldCreate : [];
  const deletes = report && Array.isArray(report.wouldDelete) ?
    report.wouldDelete : [];
  return {
    deletes: deletes.map((item) => {
      return {
        date: item.date,
        roomId: item.roomId,
        bookingId: item.bookingId,
      };
    }),
    sets: creates.map((item) => {
      return {
        date: item.date,
        roomId: item.roomId,
        bookingId: item.bookingId,
        status: item.status,
        action: item.action || "create",
      };
    }),
  };
}

/**
 * @param {Object} report
 * @return {Object}
 */
function publicExample(report) {
  return {
    bookingId: report.bookingId,
    roomId: report.roomId,
    startDate: report.startDate,
    endDate: report.endDate,
    autoCleaningAfterCheckout: report.autoCleaningAfterCheckout,
    expected: report.expected,
    actual: report.actual,
    wouldCreate: report.wouldCreate,
    wouldDelete: report.wouldDelete,
    conflicts: report.conflicts,
    skipped: report.skipped,
  };
}

/**
 * @param {Array<Object>} reports
 * @return {Object}
 */
function summarizeStayCalendarScan(reports) {
  const list = Array.isArray(reports) ? reports : [];
  const examples = [];
  let correctBookings = 0;
  let incorrectBookings = 0;
  let missingCalendarEntries = 0;
  let extraCalendarEntries = 0;
  let conflicts = 0;
  let skipped = 0;
  let wouldCreate = 0;
  let wouldDelete = 0;
  list.forEach((report) => {
    if (report.outcome === "correct") {
      correctBookings += 1;
    } else if (report.outcome === "incorrect") {
      incorrectBookings += 1;
    }
    const creates = Array.isArray(report.wouldCreate) ? report.wouldCreate : [];
    const deletes = Array.isArray(report.wouldDelete) ? report.wouldDelete : [];
    missingCalendarEntries += creates.filter((item) => {
      return item.action === "create";
    }).length;
    extraCalendarEntries += deletes.length;
    conflicts += (report.conflicts || []).length;
    skipped += (report.skipped || []).length;
    wouldCreate += creates.length;
    wouldDelete += deletes.length;
    if (report.outcome !== "correct" && examples.length < 20) {
      examples.push(publicExample(report));
    }
  });
  return {
    scannedBookings: list.length,
    correctBookings,
    incorrectBookings,
    missingCalendarEntries,
    extraCalendarEntries,
    conflicts,
    skipped,
    wouldCreate,
    wouldDelete,
    examples,
  };
}

/**
 * @param {boolean} dryRun
 * @param {Array<Object>} reports
 * @return {Object}
 */
function buildReconcileResponse(dryRun, reports) {
  const summary = summarizeStayCalendarScan(reports);
  const writes = [];
  if (!dryRun) {
    reports.forEach((report) => {
      const plan = repairWritePlan(report);
      plan.deletes.forEach((item) => {
        writes.push({op: "delete", ...item});
      });
      plan.sets.forEach((item) => {
        writes.push({op: "set", ...item});
      });
    });
  }
  return {
    ok: true,
    dryRun,
    writes,
    ...summary,
  };
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {Object} booking
 * @return {Promise<Array<Object>>}
 */
async function loadBookingCalendarDocs(firestore, shopId, booking) {
  const bookingId = normalizeString(booking.id || booking.bookingId);
  const roomId = normalizeString(booking.roomId);
  const snap = await firestore.collection("shops").doc(shopId)
      .collection("room_calendar")
      .where("bookingId", "==", bookingId)
      .get();
  const docs = snap.docs.map((doc) => {
    return {id: doc.id, ...(doc.data() || {})};
  });
  const dates = stayReleaseDateKeys(booking.startDate, booking.endDate);
  for (let i = 0; i < dates.length; i += 1) {
    const date = dates[i];
    if (!roomId || !date) {
      continue;
    }
    const ref = firestore.collection("shops").doc(shopId)
        .collection("room_calendar").doc(`${roomId}_${date}`);
    const one = await ref.get();
    if (!one.exists) {
      continue;
    }
    if (!docs.some((item) => item.id === one.id)) {
      docs.push({id: one.id, ...(one.data() || {})});
    }
  }
  return docs;
}

/**
 * @param {Object} booking
 * @param {string} bookingId
 * @param {string} reason
 * @param {string} status
 * @return {Object}
 */
function skippedBookingReport(booking, bookingId, reason, status) {
  const snapshot = bookingAutoCleaningSnapshot(booking);
  return {
    bookingId,
    roomId: normalizeString(booking.roomId),
    startDate: taipeiDateKey(booking.startDate),
    endDate: taipeiDateKey(booking.endDate),
    autoCleaningAfterCheckout: snapshot.known ? snapshot.value : null,
    autoCleaningKnown: snapshot.known,
    expected: {},
    actual: [],
    nights: [],
    wouldCreate: [],
    wouldDelete: [],
    conflicts: [],
    skipped: [issue("", reason, status, bookingId)],
    outcome: "skipped",
  };
}

/**
 * 安親、未分房、已結束的訂單不產生寫入。進行中回傳 undefined。
 * @param {Object} booking
 * @param {string} bookingId
 * @return {Object|null|undefined}
 */
function inactiveSkip(booking, bookingId) {
  const status = normalizeString(booking.status);
  const kind = normalizeString(booking.bookingKind);
  if (kind === "daycare") {
    return null;
  }
  if (!normalizeString(booking.roomId)) {
    return skippedBookingReport(booking, bookingId, "尚未分房，不校正", status);
  }
  if (ACTIVE_STATUSES.indexOf(status) < 0) {
    return skippedBookingReport(
        booking, bookingId, "非進行中住宿，不校正", status,
    );
  }
  return undefined;
}

exports.planStayCalendarRepair = planStayCalendarRepair;
exports.repairWritePlan = repairWritePlan;
exports.summarizeStayCalendarScan = summarizeStayCalendarScan;
exports.reconcileWritesAllowed = reconcileWritesAllowed;
exports.buildReconcileResponse = buildReconcileResponse;
exports.bookingAutoCleaningSnapshot = bookingAutoCleaningSnapshot;

exports.reconcileStayRoomCalendar = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const dryRun = !reconcileWritesAllowed(data);
      if (!shopId) {
        throw new HttpsError("invalid-argument", "請指定 shopId");
      }
      if (!dryRun && !bookingId) {
        throw new HttpsError(
            "invalid-argument",
            "正式修復必須指定單筆 bookingId",
        );
      }
      const uid = request.auth.uid;
      const allowed = isRootAdmin(uid) || await hasShopPermission(
          shopId, uid, "manage_bookings",
      );
      if (!allowed) {
        throw new HttpsError("permission-denied", "沒有權限校正住宿房曆");
      }
      const firestore = admin.firestore();
      const shopSnap = await firestore.collection("shops").doc(shopId).get();
      const shopAutoCleaning = autoCleaningAfterCheckout(
          shopSnap.data() || {},
      );
      if (dryRun) {
        let bookingDocs = [];
        if (bookingId) {
          const one = await firestore.collection("bookings").doc(bookingId)
              .get();
          if (!one.exists ||
            normalizeString((one.data() || {}).shopId) !== shopId) {
            throw new HttpsError("not-found", "找不到這筆住宿訂單");
          }
          bookingDocs = [one];
        } else {
          const snap = await firestore.collection("bookings")
              .where("shopId", "==", shopId)
              .limit(200)
              .get();
          bookingDocs = snap.docs.filter((doc) => {
            const item = doc.data() || {};
            return normalizeString(item.bookingKind) !== "daycare";
          });
        }
        const reports = [];
        for (let i = 0; i < bookingDocs.length; i += 1) {
          const doc = bookingDocs[i];
          const booking = {id: doc.id, ...(doc.data() || {})};
          const early = inactiveSkip(booking, doc.id);
          if (early === null) {
            continue;
          }
          if (early) {
            reports.push(early);
            continue;
          }
          const calendarDocs = await loadBookingCalendarDocs(
              firestore, shopId, booking,
          );
          reports.push(planStayCalendarRepair({booking, calendarDocs}));
        }
        return {
          ...buildReconcileResponse(true, reports),
          shopId,
          shopAutoCleaningAfterCheckoutCurrent: shopAutoCleaning,
          note: "退房日只看訂單自己的設定快照，不採用店家目前設定",
        };
      }
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      return firestore.runTransaction(async (transaction) => {
        const bookingSnap = await transaction.get(bookingRef);
        if (!bookingSnap.exists ||
          normalizeString((bookingSnap.data() || {}).shopId) !== shopId) {
          throw new HttpsError("not-found", "找不到這筆住宿訂單");
        }
        const booking = {id: bookingId, ...(bookingSnap.data() || {})};
        const early = inactiveSkip(booking, bookingId);
        if (early) {
          return {
            ...buildReconcileResponse(false, [early]),
            shopId,
            bookingId,
            shopAutoCleaningAfterCheckoutCurrent: shopAutoCleaning,
            note: "這筆沒有寫入",
          };
        }
        const roomId = normalizeString(booking.roomId);
        const ownedQuery = firestore.collection("shops").doc(shopId)
            .collection("room_calendar")
            .where("bookingId", "==", bookingId);
        const ownedSnap = await transaction.get(ownedQuery);
        const byId = {};
        ownedSnap.docs.forEach((doc) => {
          byId[doc.id] = doc;
        });
        const dates = stayReleaseDateKeys(booking.startDate, booking.endDate);
        for (let i = 0; i < dates.length; i += 1) {
          const date = dates[i];
          const id = `${roomId}_${date}`;
          if (byId[id]) {
            continue;
          }
          const ref = firestore.collection("shops").doc(shopId)
              .collection("room_calendar").doc(id);
          byId[id] = await transaction.get(ref);
        }
        const calendarDocs = Object.keys(byId).map((id) => {
          const snap = byId[id];
          return {id, ...(snap.data() || {})};
        }).filter((doc) => doc.date || doc.status || doc.bookingId);
        const report = planStayCalendarRepair({booking, calendarDocs});
        const plan = repairWritePlan(report);
        const applied = [];
        const refused = [];
        plan.deletes.forEach((item) => {
          const id = `${item.roomId}_${item.date}`;
          const snap = byId[id];
          const current = snap && snap.exists ? (snap.data() || {}) : null;
          if (!current || !canReleaseOwnedCalendar(current, bookingId)) {
            refused.push(issue(
                item.date,
                "刪除前歸屬不符，已跳過",
                normalizeString(current && current.status),
                normalizeString(current && current.bookingId),
            ));
            return;
          }
          if (calendarBlocksRoom(current.status) &&
            (isManualCalendarStatus(current.status) ||
              normalizeString(current.status) === "cleaning")) {
            refused.push(issue(
                item.date,
                "人工房務狀態，已跳過",
                normalizeString(current.status),
                bookingId,
            ));
            return;
          }
          transaction.delete(snap.ref);
          applied.push({op: "delete", ...item});
        });
        plan.sets.forEach((item) => {
          const id = `${item.roomId}_${item.date}`;
          const snap = byId[id];
          const current = snap && snap.exists ? (snap.data() || {}) : null;
          if (current) {
            const owner = normalizeString(current.bookingId);
            const status = normalizeString(current.status);
            const blocked = isManualCalendarStatus(status) ||
              status === "cleaning" ||
              (owner && owner !== bookingId) ||
              (!owner && calendarBlocksRoom(status));
            if (blocked) {
              refused.push(issue(
                  item.date,
                  "目標日已有其他資料，已跳過",
                  status,
                  owner,
              ));
              return;
            }
          }
          const ref = firestore.collection("shops").doc(shopId)
              .collection("room_calendar").doc(id);
          transaction.set(ref, {
            roomId: item.roomId,
            date: item.date,
            status: item.status,
            bookingId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          applied.push({op: "set", ...item});
        });
        return {
          ok: true,
          dryRun: false,
          shopId,
          bookingId,
          shopAutoCleaningAfterCheckoutCurrent: shopAutoCleaning,
          note: "退房日只看訂單自己的設定快照，不採用店家目前設定",
          writes: applied,
          refused,
          ...summarizeStayCalendarScan([report]),
        };
      });
    },
);
