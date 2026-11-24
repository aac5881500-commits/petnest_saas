/* eslint-disable require-jsdoc, max-len */
const MAX_WINDOW_MS = 2 * 60 * 60 * 1000;
function validWindow(raw, bookingId, booking, now) {
  if (!raw || raw.enabled !== true || raw.bookingId !== bookingId || raw.shopId !== booking.shopId || raw.bookingCode !== booking.bookingCode || raw.syncCustomer !== true) return null;
  const from = Date.parse(raw.startedAt);
  if (raw.mode === "permanent") {
    if (bookingId !== "qcxaDmx9Qdn3W75LvGIP" || booking.shopId !== "SHOP0017" || booking.bookingCode !== "SHOP0017-B000016" || !Number.isFinite(from) || now < from) return null;
    return {mode: "permanent", startedAt: raw.startedAt, expiresAt: null, bookingId, bookingCode: raw.bookingCode};
  }
  const until = Date.parse(raw.expiresAt);
  if (!Number.isFinite(from) || !Number.isFinite(until) || until <= from || until - from > MAX_WINDOW_MS || now < from || now >= until) return null;
  return {startedAt: raw.startedAt, expiresAt: raw.expiresAt, bookingId, bookingCode: raw.bookingCode};
}
async function readWindow(tx, db, bookingId, booking, now) {
  const snap = await tx.get(db.collection("internal_booking_time_tests").doc(bookingId));
  return validWindow(snap.exists ? snap.data() : null, bookingId, booking, now);
}
module.exports = {validWindow, readWindow};
