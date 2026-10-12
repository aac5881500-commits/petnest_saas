const test = require("node:test");
const assert = require("node:assert/strict");
const policy = require("./platform_user_policy");

function operator(extra) {
  return Object.assign({
    uid: "manager-1",
    isRoot: false,
    role: "platform_admin",
    enabled: true,
    permissions: [
      "manage_platform_admins",
      "view_shops",
      "view_platform_logs",
    ],
  }, extra);
}

function target(extra) {
  return Object.assign({
    uid: "staff-1",
    isRoot: false,
    role: "platform_staff",
    enabled: true,
    permissions: ["view_shops", "legacy_custom_key"],
  }, extra);
}

test("平台員工不能修改自己的權限", () => {
  assert.throws(
      () => policy.planPlatformUserUpdate({
        operator: operator({
          uid: "staff-1",
          role: "platform_staff",
          permissions: ["manage_platform_admins"],
        }),
        target: target({uid: "staff-1"}),
        name: "員工",
        email: "staff@example.com",
        role: "platform_staff",
        enabled: true,
        permissions: ["manage_platform_admins", "view_shops"],
      }),
      /不能修改自己的角色或權限/,
  );
});

test("平台管理員不能把自己提升為最高管理員", () => {
  assert.throws(
      () => policy.planPlatformUserUpdate({
        operator: operator(),
        target: target({uid: "other-1"}),
        name: "管理員",
        email: "manager@example.com",
        role: "super_admin",
        enabled: true,
        permissions: ["view_shops"],
      }),
      /不能任命最高管理員/,
  );
});

test("不能修改最高管理員", () => {
  assert.throws(
      () => policy.planPlatformUserUpdate({
        operator: operator(),
        target: target({role: "super_admin"}),
        name: "最高",
        email: "super@example.com",
        role: "platform_admin",
        enabled: true,
        permissions: ["view_shops"],
      }),
      /不能修改最高管理員/,
  );
});

test("平台員工不能取得核心金流權限", () => {
  const plan = policy.planPlatformUserUpdate({
    operator: operator({
      permissions: [
        "manage_platform_admins",
        "manage_payment_settings",
        "view_shops",
      ],
    }),
    target: target({permissions: ["view_shops"]}),
    name: "員工",
    email: "staff@example.com",
    role: "platform_staff",
    enabled: true,
    permissions: ["view_shops", "manage_payment_settings", "all"],
  });
  assert.equal(plan.permissions.includes("manage_payment_settings"), false);
  assert.equal(plan.permissions.includes("all"), false);
  assert.equal(plan.permissions.includes("view_shops"), true);
});

test("停用帳號不能規劃平台人員更新", () => {
  assert.throws(
      () => policy.planPlatformUserUpdate({
        operator: operator({enabled: false}),
        target: target(),
        name: "員工",
        email: "staff@example.com",
        role: "platform_staff",
        enabled: true,
        permissions: ["view_shops"],
      }),
      /已停用/,
  );
});

test("權限更新保留未知鍵與既有最高管理員專屬權限", () => {
  const plan = policy.planPlatformUserUpdate({
    operator: operator({isRoot: true, role: "super_admin", permissions: []}),
    target: target({
      permissions: [
        "view_shops",
        "manage_payment_settings",
        "legacy_custom_key",
      ],
    }),
    name: "員工",
    email: "staff@example.com",
    role: "platform_admin",
    enabled: false,
    permissions: ["view_platform_members"],
  });
  assert.deepEqual(plan.added, ["view_platform_members"]);
  assert.deepEqual(plan.removed, ["view_shops"]);
  assert.equal(plan.permissions.includes("manage_payment_settings"), true);
  assert.equal(plan.permissions.includes("legacy_custom_key"), true);
  assert.equal(plan.permissions.includes("view_platform_members"), true);
  assert.equal(plan.role, "platform_admin");
  assert.equal(plan.enabled, false);
});

test("平台管理員不能授予自己沒有的權限", () => {
  const plan = policy.planPlatformUserUpdate({
    operator: operator(),
    target: target({permissions: ["manage_activation_codes"]}),
    name: "員工",
    email: "staff@example.com",
    role: "platform_staff",
    enabled: true,
    permissions: ["view_shops", "manage_activation_codes", "manage_sales"],
  });
  assert.equal(plan.permissions.includes("view_shops"), true);
  assert.equal(plan.permissions.includes("manage_sales"), false);
  assert.equal(plan.permissions.includes("manage_activation_codes"), true);
});

test("新增權限清單不含最高管理員專屬鍵，並補上既有可分配鍵", () => {
  const created = policy.normalizePermissions([
    "manage_sales",
    "view_own_sales",
    "manage_subscription_finance",
    "manage_platform_media",
    "manage_payment_settings",
    "all",
  ]);
  assert.deepEqual(created, [
    "manage_sales",
    "view_own_sales",
    "manage_subscription_finance",
    "manage_platform_media",
  ]);
});
