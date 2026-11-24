/* eslint-disable require-jsdoc */
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
test("standalone deployment initializes Firebase before loading the medication handler", () => {
  for (const existing of [false, true]) {
    const apps = existing ? [{}] : [];
    let initialized = 0;
    const handler = () => {};
    const context = {exports: {}, require(name) {
      if (name === "firebase-admin") return {apps, initializeApp() { initialized++; apps.push({}); }};
      assert.equal(name, "./medication_functions");
      assert.equal(apps.length, 1, "Admin app must exist before handlers are loaded");
      return {manageBookingMedication: handler};
    }};
    vm.runInNewContext(fs.readFileSync(require.resolve("./standalone_entry"), "utf8"), context);
    assert.equal(initialized, existing ? 0 : 1);
    assert.deepEqual(Object.keys(context.exports), ["manageBookingMedication"]);
    assert.equal(context.exports.manageBookingMedication, handler);
  }
});
