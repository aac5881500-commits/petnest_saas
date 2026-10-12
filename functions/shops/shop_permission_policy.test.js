const test = require("node:test");
const assert = require("node:assert/strict");
const policy = require("./shop_permission_policy");

test("老闆專屬權限不能靠勾選開放", () => {
  assert.equal(policy.isOwnerOnlyPermission("manage_payment_settings"), true);
  assert.equal(policy.isOwnerOnlyPermission("manage_bookings"), false);
});

test("店長不能把自己或別人升成老闆或店長", () => {
  assert.ok(policy.roleChangeBlock("manager", "staff", "manager", false));
  assert.ok(policy.roleChangeBlock("manager", "manager", "manager", true));
  assert.equal(policy.roleChangeBlock("manager", "staff", "staff", false), null);
  assert.ok(policy.roleChangeBlock("staff", "staff", "staff", true));
  assert.ok(policy.roleChangeBlock("owner", "staff", "owner", false));
});

test("敏感通知只有老闆可讀", () => {
  assert.equal(policy.audienceForType("payment_failed"), "owner");
  assert.equal(policy.audienceForType("plan"), "owner");
  assert.equal(policy.audienceForType("system"), "everyone");
  assert.equal(policy.canReadNotice("manager", true, "owner"), false);
  assert.equal(policy.canReadNotice("staff", true, "owner"), false);
  assert.equal(policy.canReadNotice("owner", false, "owner"), true);
  assert.equal(policy.canReadNotice("staff", false, "announcement"), false);
  assert.equal(policy.canReadNotice("staff", true, "announcement"), true);
});
