"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {customerPushAllowed: allowed} = require("./customer_push_policy");
test("muting shop A does not mute shop B or A announcements", () => {
  const prefs = {shopOverrides: {A: {shopMarketing: false}}};
  assert.equal(allowed({category: "shop_marketing"}, prefs, "A"), false);
  assert.equal(allowed({category: "shop_marketing"}, prefs, "B"), true);
  assert.equal(allowed({category: "shop_notice"}, prefs, "A"), true);
});
test("global mute always wins over local opt-in", () => {
  assert.equal(allowed({category: "shop_notice"}, {shopNotice: false, shopOverrides: {A: {shopNotice: true}}}, "A"), false);
});
test("mandatory-looking shop promotions cannot bypass mute", () => {
  assert.equal(allowed({category: "shop_marketing", isMandatory: true}, {shopOverrides: {A: {shopMarketing: false}}}, "A"), false);
});
test("transactional and platform important remain enabled with every optional switch off", () => {
  const prefs = {enabled: false, checkInReminder: false, shopNotice: false, shopOverrides: {A: {shopNotice: false}}};
  assert.equal(allowed({category: "transactional"}, prefs, "A"), true);
  assert.equal(allowed({category: "platform_important"}, prefs, "A"), true);
});
test("legacy missing prefs use enabled default; platform settings independent", () => {
  assert.equal(allowed({category: "shop_notice"}, {}, "A"), true);
  assert.equal(allowed({category: "platform_marketing"}, {platformMarketing: false}, "A"), false);
  assert.equal(allowed({category: "shop_marketing"}, {enabled: false}, "A"), false);
});
