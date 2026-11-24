const test = require('node:test');
const assert = require('node:assert/strict');
const {isStayCancellationStatusAllowed} = require('./stay_cancellation_policy');
test('temporary staff cancellation permits unlocked checked in stay', () => {
  assert.equal(isStayCancellationStatusAllowed({status:'checked_in', paidAmount:3600}, true), true);
});
test('customer cannot cancel checked in or confirmed stays', () => {
  for (const status of ['checked_in','confirmed']) assert.equal(isStayCancellationStatusAllowed({status}, false), false);
  assert.equal(isStayCancellationStatusAllowed({status:'pending'}, false), true);
});
test('locked and completed stays remain blocked', () => {
  assert.equal(isStayCancellationStatusAllowed({status:'checked_in',settlementLocked:true}, true), false);
  for (const status of ['checked_out','completed','cancelled']) assert.equal(isStayCancellationStatusAllowed({status}, true), false);
});
test('existing staff cancellation states remain permitted and financial data unchanged', () => {
  for (const status of ['pending','pending_confirmation','unpaid','confirmed']) assert.equal(isStayCancellationStatusAllowed({status}, true), true);
  const booking = {status:'checked_in',paidAmount:3600,paymentStatus:'paid',checkInAt:'2026-11-24'};
  const before = JSON.stringify(booking);
  isStayCancellationStatusAllowed(booking, true);
  assert.equal(JSON.stringify(booking), before);
});
