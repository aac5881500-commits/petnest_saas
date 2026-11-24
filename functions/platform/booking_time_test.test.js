/* eslint-disable require-jsdoc */
const test = require("node:test");
const assert = require("node:assert/strict");
const {validWindow} = require("./booking_time_test");
const from = Date.parse("2026-11-22T14:00:00Z");
const raw = {enabled: true, bookingId: "b", shopId: "s", bookingCode: "TEST", syncCustomer: true, startedAt: new Date(from).toISOString(), expiresAt: new Date(from + 7200000).toISOString()};
const booking = {shopId: "s", bookingCode: "TEST"};
test("only matching order is active, exactly two hours then automatically expires", () => {
 assert.ok(validWindow(raw, "b", booking, from));
 assert.ok(validWindow(raw, "b", booking, from + 7199999));
 assert.equal(validWindow(raw, "b", booking, from + 7200000), null);
 assert.equal(validWindow(raw, "other", booking, from), null);
 assert.equal(validWindow(raw, "b", {...booking, shopId: "other"}, from), null);
 assert.equal(validWindow(raw, "b", booking, from - 1), null);
});
test("cannot extend beyond two hours or enable via malformed metadata", () => {
 assert.equal(validWindow({...raw, expiresAt: new Date(from + 7200001).toISOString()}, "b", booking, from), null);
 assert.equal(validWindow({...raw, enabled: false}, "b", booking, from), null);
 assert.equal(validWindow({...raw, syncCustomer: false}, "b", booking, from), null);
 assert.equal(validWindow(null, "b", booking, from), null);
});

test("permanent mode is pinned to the one authorized test order, never to other orders", () => {
 const id = "qcxaDmx9Qdn3W75LvGIP", b = {shopId: "SHOP0017", bookingCode: "SHOP0017-B000016"};
 const config = {...raw, mode: "permanent", bookingId: id, ...b}; delete config.expiresAt;
 assert.ok(validWindow(config, id, b, from + 365 * 86400000));
 assert.equal(validWindow(config, id, b, from + 365 * 86400000).expiresAt, null);
 assert.equal(validWindow({...config, bookingId: "other"}, "other", b, from), null);
 assert.equal(validWindow({...config, enabled: false}, id, b, from), null);
 assert.equal(validWindow({...raw, mode: "permanent"}, "b", booking, from), null);
});
