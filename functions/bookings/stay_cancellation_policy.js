// Temporary testing switch: restore false with the matching Dart UI switch.
const TEMPORARILY_ALLOW_CHECKED_IN_CANCEL = true;
function isStayCancellationStatusAllowed(booking, adminCancel) {
  const status = String(booking.status || "").trim();
  if (!adminCancel) return ["pending", "unpaid"].includes(status);
  if (["pending", "pending_confirmation", "unpaid", "confirmed"].includes(status)) return true;
  return TEMPORARILY_ALLOW_CHECKED_IN_CANCEL && status === "checked_in" && booking.settlementLocked !== true;
}
module.exports = {isStayCancellationStatusAllowed, TEMPORARILY_ALLOW_CHECKED_IN_CANCEL};
