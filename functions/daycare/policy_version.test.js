// 檔案名稱：functions/daycare/policy_version.test.js
// 功能說明：安親條款版本不可被住宿／退款全域 version 誤傷

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  servicePolicyVersion,
  summarizePolicyForService,
} = require("./daycare_utils");

test("confirmed daycare v1 is not updated by stay global version", () => {
  const policy = {
    version: 8,
    accommodationVersion: 8,
    daycareVersion: 1,
    serviceVersions: {accommodation: 8, daycare: 1},
    sections: {a: "安親內容"},
    enabled: {a: true},
    sectionApplicableServices: {a: ["daycare"]},
  };
  assert.equal(servicePolicyVersion(policy, "daycare"), 1);
  assert.equal(summarizePolicyForService(policy, "daycare").version, 1);
  assert.equal(servicePolicyVersion(policy, "accommodation"), 8);
});

test("legacy shared policy uses global version for daycare", () => {
  const policy = {
    version: 1,
    sections: {a: "共用"},
    enabled: {a: true},
    sectionApplicableServices: {a: ["accommodation", "daycare"]},
  };
  assert.equal(servicePolicyVersion(policy, "daycare"), 1);
  assert.equal(summarizePolicyForService(policy, "daycare").required, true);
});
