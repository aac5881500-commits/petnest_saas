// 店家權限 V2 的純判斷。Firestore Rules 另有對應限制。

const OWNER_ONLY_KEYS = new Set(["manage_payment_settings"]);

/**
 * @param {string} key
 * @return {boolean}
 */
function isOwnerOnlyPermission(key) {
  return OWNER_ONLY_KEYS.has(key);
}

/**
 * @param {string} operatorRole
 * @param {string} targetRole
 * @param {string} nextRole
 * @param {boolean} editingSelf
 * @return {string|null}
 */
function roleChangeBlock(operatorRole, targetRole, nextRole, editingSelf) {
  if (nextRole === "owner" || targetRole === "owner") {
    return "不可變更老闆角色";
  }
  if (operatorRole === "staff") {
    return "員工不可修改權限";
  }
  if (operatorRole === "manager") {
    if (editingSelf) return "店長不可修改自己的權限";
    if (targetRole === "manager" || nextRole !== "staff") {
      return "店長不可任命或修改店長";
    }
  }
  if (operatorRole !== "owner" && operatorRole !== "manager") {
    return "沒有權限管理成員";
  }
  return null;
}

/**
 * @param {string} type
 * @return {string}
 */
function audienceForType(type) {
  switch (type) {
    case "system":
      return "everyone";
    case "update":
    case "review":
      return "announcement";
    case "warning":
      return "managers";
    default:
      return "owner";
  }
}

/**
 * @param {string} role
 * @param {boolean} canViewAnnouncements
 * @param {string} audience
 * @return {boolean}
 */
function canReadNotice(role, canViewAnnouncements, audience) {
  if (role === "owner") return true;
  if (audience === "owner" || audience === "") return false;
  if (audience === "managers") return role === "manager";
  if (audience === "announcement") {
    return role === "manager" || canViewAnnouncements;
  }
  if (audience === "everyone") {
    return role === "manager" || role === "staff";
  }
  return false;
}

module.exports = {
  isOwnerOnlyPermission,
  roleChangeBlock,
  audienceForType,
  canReadNotice,
};
