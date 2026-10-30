"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const {locationInput} = require("./shop_map_location_policy");
/** @return {Object} Isolated callable and writes. */
function fixture() {
  const writes = [];
  const rows = {"shops/s": {ownerUid: "owner", city: "新竹市",
    district: "東區", address: "測試路1號", isPublic: false},
  "shop_members/s_staff": {uid: "staff", shopId: "s", role: "staff"}};
  const db = {collection: (name) => ({doc: (id) => ({path: name+"/"+id})}),
    runTransaction: async (fn) => fn({get: async (ref) => ({
      exists: !!rows[ref.path], get: (key) => (rows[ref.path] || {})[key],
    }), update: (ref, data) => writes.push({path: ref.path, data})})};
  const firestore = () => db;
  firestore.FieldValue = {delete: () => "DELETE", serverTimestamp: () => 123};
  /** Callable error fake. */
  class HttpsError extends Error {
    /**
     * @param {string} code Callable status.
     * @param {string} message User message.
     */
    constructor(code, message) {
      super(message); this.code = code;
    }
  }
  const output = {};
  vm.runInNewContext(fs.readFileSync(__dirname+"/shop_map_location.js", "utf8"), {
    exports: output, require: (name) => name === "firebase-admin" ? {firestore} :
      name === "firebase-functions/v2/https" ?
      {onCall: (_, fn) => fn, HttpsError} : require(name),
  });
  const input = {shopId: "s", latitude: 24.8, longitude: 120.9,
    confirmed: true, expectedAddress: "新竹市東區測試路1號"};
  return {writes, input, call: (uid, data = input) =>
    output.saveShopMapLocation({auth: uid ? {uid} : null, data})};
}
test("validates finite confirmed coordinates and supports removal", () => {
  assert.equal(locationInput({remove: true}), null);
  assert.equal(locationInput({latitude: 25, longitude: 121,
    confirmed: true}).source, "owner_confirmed");
  for (const data of [{latitude: 91, longitude: 121},
    {latitude: 25, longitude: 181}, {latitude: NaN, longitude: 121},
    {latitude: "25", longitude: 121}, {latitude: 25, longitude: 121}]) {
    assert.throws(() => locationInput(data));
  }
});
test("rejects anonymous, staff and unrelated accounts without writes", async () => {
  const f = fixture();
  await assert.rejects(f.call(null), {code: "unauthenticated"});
  for (const uid of ["staff", "other"]) {
    await assert.rejects(f.call(uid), {code: "permission-denied"});
  }
  assert.equal(f.writes.length, 0);
});
test("owner saves location only without publishing the shop", async () => {
  const f = fixture(); await f.call("owner");
  assert.equal(f.writes.length, 1);
  assert.equal(f.writes[0].data.mapLocation.latitude, 24.8);
  assert.equal(f.writes[0].data.mapLocation.addressSnapshot,
      f.input.expectedAddress);
  assert.equal(f.writes[0].data.isPublic, undefined);
  assert.equal(f.writes[0].data.ownerUid, undefined);
});
test("stale address is rejected; owner can remove location", async () => {
  const f = fixture();
  await assert.rejects(f.call("owner", {...f.input, expectedAddress: "old"}),
      {code: "failed-precondition"});
  assert.equal(f.writes.length, 0);
  await f.call("owner", {shopId: "s", remove: true});
  assert.equal(f.writes[0].data.mapLocation, "DELETE");
});
