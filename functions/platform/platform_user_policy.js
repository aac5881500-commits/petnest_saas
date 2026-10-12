// 檔案名稱：functions/platform/platform_user_policy.js
// 功能說明：平台人員新增與更新的共用權限規則。
// 不信任前端傳入的角色，也不讓非最高管理員取得專屬權限。

const SUPER_ADMIN_ROLE = "super_admin";
const PLATFORM_ADMIN_ROLE = "platform_admin";
const DEVELOPER_ADMIN_ROLE = "developer_admin";
const PLATFORM_STAFF_ROLE = "platform_staff";

const SUPER_ONLY_PERMISSIONS = [
  "view_payment_sensitive_data",
  "manage_payment_settings",
  "emergency_disable_payment",
  "access_developer_tools",
  "all",
];

const ASSIGNABLE_PERMISSIONS = [
  "view_shops",
  "manage_shop_status",
  "review_shop_requests",
  "manage_shop_subscriptions",
  "view_payment_status",
  "review_payment_applications",
  "view_platform_members",
  "manage_platform_members",
  "manage_support_requests",
  "manage_account_delete_requests",
  "manage_platform_reviews",
  "manage_platform_policies",
  "manage_activation_codes",
  "manage_sales",
  "view_own_sales",
  "manage_subscription_finance",
  "view_platform_logs",
  "manage_platform_admins",
  "manage_platform_media",
];

const ALLOWED_ROLES = [
  PLATFORM_ADMIN_ROLE,
  DEVELOPER_ADMIN_ROLE,
  PLATFORM_STAFF_ROLE,
];

/**
 * @param {*} value 原始值
 * @return {string}
 */
function normalizeString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return value.toString().trim();
}

/**
 * @param {*} value 權限陣列
 * @return {string[]}
 */
function normalizePermissions(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return [
    ...new Set(
        value
            .map((permission) => normalizeString(permission))
            .filter((permission) =>
              ASSIGNABLE_PERMISSIONS.includes(permission),
            ),
    ),
  ];
}

/**
 * @param {Object} operator 操作者
 * @return {boolean}
 */
function canManagePlatformUsers(operator) {
  if (!operator || operator.enabled !== true) {
    return false;
  }
  if (operator.isRoot === true || operator.role === SUPER_ADMIN_ROLE) {
    return true;
  }
  const permissions = Array.isArray(operator.permissions) ?
    operator.permissions :
    [];
  return permissions.includes("manage_platform_admins");
}

/**
 * 操作者實際可以新授予的權限。最高管理員專屬權限一律排除。
 * @param {Object} operator 操作者
 * @param {*} requested 前端勾選
 * @return {string[]}
 */
function grantablePermissions(operator, requested) {
  const cleaned = normalizePermissions(requested);
  if (operator && (operator.isRoot === true ||
    operator.role === SUPER_ADMIN_ROLE)) {
    return cleaned;
  }
  const owned = new Set(
      Array.isArray(operator && operator.permissions) ?
        operator.permissions :
        [],
  );
  return cleaned.filter((permission) => owned.has(permission));
}

/**
 * @param {string[]} previous 既有權限
 * @param {string[]} next 寫入權限
 * @return {{added: string[], removed: string[]}}
 */
function permissionDiff(previous, next) {
  const before = new Set(previous);
  const after = new Set(next);
  return {
    added: [...after].filter((permission) => !before.has(permission)),
    removed: [...before].filter((permission) => !after.has(permission)),
  };
}

/**
 * 計算一次平台人員更新。失敗時丟出 Error，呼叫端不得寫入。
 * @param {Object} input 操作者、目標與草稿
 * @return {Object}
 */
function planPlatformUserUpdate(input) {
  const operator = input.operator || {};
  const target = input.target || {};
  const role = normalizeString(input.role);
  const enabled = input.enabled === true;
  const name = normalizeString(input.name);
  const email = normalizeString(input.email).toLowerCase();

  if (operator.enabled !== true) {
    throw new Error("你的平台管理帳號目前已停用。");
  }
  if (!canManagePlatformUsers(operator)) {
    throw new Error("你沒有管理平台人員的權限。");
  }
  if (!target.uid) {
    throw new Error("找不到平台人員資料。");
  }
  if (target.isRoot === true) {
    throw new Error("不能修改永久根管理員。");
  }
  if (target.role === SUPER_ADMIN_ROLE) {
    throw new Error("不能修改最高管理員。");
  }
  if (operator.isRoot !== true && target.uid === operator.uid) {
    throw new Error("不能修改自己的角色或權限。");
  }
  if (role === SUPER_ADMIN_ROLE) {
    throw new Error("不能任命最高管理員。");
  }
  if (!ALLOWED_ROLES.includes(role)) {
    throw new Error("平台角色不正確。");
  }
  if (!name) {
    throw new Error("請輸入姓名或稱呼。");
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new Error("Email 格式不正確。");
  }

  const previous = Array.isArray(target.permissions) ?
    target.permissions.map((permission) => normalizeString(permission))
        .filter((permission) => permission.length > 0) :
    [];
  const requested = grantablePermissions(operator, input.permissions);
  const operatorIsSuper = operator.isRoot === true ||
    operator.role === SUPER_ADMIN_ROLE;
  const owned = new Set(
      Array.isArray(operator.permissions) ? operator.permissions : [],
  );
  const preserved = previous.filter((permission) => {
    if (SUPER_ONLY_PERMISSIONS.includes(permission)) {
      return true;
    }
    if (!ASSIGNABLE_PERMISSIONS.includes(permission)) {
      return true;
    }
    if (operatorIsSuper) {
      return false;
    }
    return !owned.has(permission);
  });
  const permissions = [...new Set([...requested, ...preserved])];
  const diff = permissionDiff(previous, permissions);

  return {
    name,
    email,
    role,
    enabled,
    permissions,
    added: diff.added,
    removed: diff.removed,
    previousRole: normalizeString(target.role),
    previousEnabled: target.enabled === true,
  };
}

module.exports = {
  SUPER_ADMIN_ROLE,
  PLATFORM_ADMIN_ROLE,
  DEVELOPER_ADMIN_ROLE,
  PLATFORM_STAFF_ROLE,
  SUPER_ONLY_PERMISSIONS,
  ASSIGNABLE_PERMISSIONS,
  ALLOWED_ROLES,
  normalizeString,
  normalizePermissions,
  canManagePlatformUsers,
  grantablePermissions,
  planPlatformUserUpdate,
};
