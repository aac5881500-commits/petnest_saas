// 檔案名稱：functions/legal_pet/access.js
// 功能說明：平台業者資料庫與認證審核的權限判斷。

const ROOT_ADMIN_UID = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";

const DIRECTORY_PERMISSIONS = [
  "view_shops",
  "manage_shop_status",
  "review_shop_requests",
];

const REVIEW_PERMISSIONS = [
  "review_shop_requests",
];

/**
 * @param {Object} user platform_users 資料，根管理員可只帶 uid
 * @param {string[]} required 需要的權限
 * @return {boolean}
 */
function hasPlatformAccess(user, required) {
  const data = user || {};
  if (data.uid === ROOT_ADMIN_UID) {
    return true;
  }
  if (data.enabled !== true) {
    return false;
  }
  if (data.role === "super_admin") {
    return true;
  }
  const permissions = Array.isArray(data.permissions) ? data.permissions : [];
  return required.some((permission) => {
    return permissions.indexOf(permission) >= 0;
  });
}

/**
 * @param {Object} user 平台人員
 * @return {boolean}
 */
function canViewDirectory(user) {
  return hasPlatformAccess(user, DIRECTORY_PERMISSIONS);
}

/**
 * @param {Object} user 平台人員
 * @return {boolean}
 */
function canReviewShopRequests(user) {
  return hasPlatformAccess(user, REVIEW_PERMISSIONS);
}

module.exports = {
  ROOT_ADMIN_UID,
  DIRECTORY_PERMISSIONS,
  REVIEW_PERMISSIONS,
  hasPlatformAccess,
  canViewDirectory,
  canReviewShopRequests,
};
