// 檔案名稱：functions/legal_pet/review_policy.js
// 功能說明：認證送件與核准的純規則。不信任客戶端自稱查核成功。

const {text, normalizeLicense, compareAddress} = require("./normalize");
const {TAIWAN_PLACES} = require("./taiwan_places");

/**
 * @param {Object} shop 正式店家
 * @param {Object} snapshot 送件快照
 * @return {boolean}
 */
function snapshotMatchesShop(shop, snapshot) {
  const current = shop || {};
  const saved = snapshot || {};
  return text(current.licenseNumber) === text(saved.licenseNumber) &&
    text(current.taxId) === text(saved.taxId) &&
    text(current.name) === text(saved.name) &&
    text(current.city) === text(saved.city) &&
    text(current.district) === text(saved.district) &&
    text(current.address) === text(saved.address);
}

/**
 * @param {Object} input 後端重算後的查核
 * @return {{error: string, checkResult: string, addressComparison: string}}
 */
function planCertificationSubmit(input) {
  const checkResult = input.checkResult || "unavailable";
  const addressComparison = input.addressComparison || "unavailable";
  const note = text(input.addressDifferenceNote);
  const proof = text(input.addressProofImageUrl);
  if (addressComparison === "mismatch" && (!note || !proof)) {
    return {
      error: "營業地址與政府登記地址有明顯差異，需填寫差異說明並上傳相關證明",
      checkResult: checkResult,
      addressComparison: addressComparison,
    };
  }
  if (checkResult === "none" || checkResult === "unavailable" ||
      checkResult === "stale" || checkResult === "expired" ||
      checkResult === "multiple" || checkResult === "matched" ||
      checkResult === "invalid" || checkResult === "incomplete") {
    return {
      error: "",
      checkResult: checkResult,
      addressComparison: addressComparison,
    };
  }
  return {
    error: "",
    checkResult: "unavailable",
    addressComparison: addressComparison,
  };
}

/**
 * @param {Object} shop 店家
 * @param {Object} record 單一政府紀錄，可為 null
 * @return {string}
 */
function addressResultFor(shop, record) {
  if (!record) {
    return "unavailable";
  }
  return compareAddress(shop, record.legaladdress, record.countyCode).result;
}

/**
 * @param {Object} input 申請、店家、綁定與審核選擇
 * @return {Object}
 */
function buildReviewPlan(input) {
  const action = input.action;
  const request = input.request || {};
  const note = text(input.reviewNote);
  if (request.status !== "pending") {
    return {error: "這張申請已不是待審核"};
  }
  if (action === "reject" || action === "supplement") {
    if (!note) {
      return {error: "請填寫原因"};
    }
    return {
      error: "",
      requestPatch: {
        status: action === "reject" ? "rejected" : "supplement",
        reviewNote: note,
        reviewedBy: input.actorUid || "",
      },
      shopPatch: null,
      linkPatch: null,
    };
  }
  if (action !== "approve") {
    return {error: "不支援的審核動作"};
  }
  if (request.requestType === "fullVerify") {
    return planFullVerifyApproval(input, note);
  }
  return planFieldApproval(input, note);
}

/**
 * @param {Object} input 審核輸入
 * @param {string} note 理由
 * @return {Object}
 */
function planFullVerifyApproval(input, note) {
  const request = input.request || {};
  const shop = input.shop || {};
  const snapshot = request.shopSnapshot || {};
  if (!snapshotMatchesShop(shop, snapshot)) {
    return {error: "正式字號或地址已與送件資料不同，請店家重新查核後再送審"};
  }
  const approveLicense = input.approveLicense === true;
  const approveTaxId = input.approveTaxId === true;
  const approvePublic = input.approvePublic === true;
  if (!approveLicense && !approveTaxId && !approvePublic &&
      input.applyProposedAddress !== true) {
    return {error: "請選擇要核准的項目"};
  }
  const shopPatch = {};
  let linkPatch = null;
  let clearLinkId = "";
  const normalized = normalizeLicense(shop.licenseNumber);
  if (approveLicense) {
    if (!normalized) {
      return {error: "店家尚未填寫特寵字號，不能核准字號"};
    }
    const link = input.link || {};
    const otherShop = text(link.certifiedShopId);
    if (otherShop && otherShop !== text(shop.shopId || input.shopId)) {
      if (input.transferLicense !== true) {
        return {
          error: "此字號已有其他店家認證綁定，請先選擇轉移或解除，不能直接覆蓋",
          conflictShopId: otherShop,
        };
      }
      linkPatch = {
        certifiedShopId: text(shop.shopId || input.shopId),
        transferredFromShopId: otherShop,
      };
    } else {
      linkPatch = {
        certifiedShopId: text(shop.shopId || input.shopId),
        transferredFromShopId: "",
      };
    }
    shopPatch.licenseVerified = true;
    shopPatch.normalizedLicenseNumber = normalized;
  }
  if (approveTaxId) {
    if (!text(shop.taxId)) {
      return {error: "店家尚未填寫統編，不能核准統編"};
    }
    shopPatch.taxIdVerified = true;
  }
  if (input.applyProposedAddress === true) {
    const proposed = request.proposedAddress || {};
    if (!text(proposed.city) || !text(proposed.district) ||
        !text(proposed.address)) {
      return {error: "擬更正地址不完整"};
    }
    const districts = TAIWAN_PLACES[text(proposed.city)] || [];
    if (districts.indexOf(text(proposed.district)) < 0) {
      return {error: "擬更正地址的縣市或區域無法對應"};
    }
    shopPatch.city = text(proposed.city);
    shopPatch.district = text(proposed.district);
    shopPatch.address = text(proposed.address);
    shopPatch.addressSetupCompleted = true;
    if (shop.licenseVerified === true && approveLicense !== true) {
      shopPatch.licenseVerified = false;
      shopPatch.isPublic = false;
      clearLinkId = normalizeLicense(shop.licenseNumber);
    }
  }
  const licenseWillBeVerified = shopPatch.licenseVerified === true ||
    (shop.licenseVerified === true && shopPatch.licenseVerified !== false);
  const taxWillBeVerified = shopPatch.taxIdVerified === true ||
    shop.taxIdVerified === true;
  if (approvePublic) {
    if (!licenseWillBeVerified || !taxWillBeVerified) {
      return {error: "平台公開需字號認證與統編認證都通過"};
    }
    shopPatch.isPublic = true;
  }
  const previousShopId = linkPatch ? linkPatch.transferredFromShopId : "";
  return {
    error: "",
    requestPatch: {
      status: "approved",
      reviewNote: note || "平台已審核",
      reviewedBy: input.actorUid || "",
      approvedLicense: approveLicense,
      approvedTaxId: approveTaxId,
      approvedPublic: approvePublic,
    },
    shopPatch: shopPatch,
    linkPatch: linkPatch,
    linkId: normalized,
    clearLinkId: clearLinkId,
    previousShopId: previousShopId,
    previousShopPatch: previousShopId ? {
      licenseVerified: false,
      isPublic: false,
    } : null,
  };
}

/**
 * @param {Object} input 一般重要資料修改
 * @param {string} note 理由
 * @return {Object}
 */
function planFieldApproval(input, note) {
  const request = input.request || {};
  const shop = input.shop || {};
  const type = request.requestType;
  const shopPatch = {};
  let clearLinkId = "";
  if (type === "address") {
    const city = text(request.newCity);
    const district = text(request.newDistrict);
    const address = text(request.newAddress);
    if (!city || !district || !address) {
      return {error: "地址申請缺少縣市、區域或詳細地址"};
    }
    const districts = TAIWAN_PLACES[city] || [];
    if (districts.indexOf(district) < 0) {
      return {error: "地址申請的縣市或區域無法對應"};
    }
    shopPatch.city = city;
    shopPatch.district = district;
    shopPatch.address = address;
    shopPatch.addressSetupCompleted = true;
    if (shop.licenseVerified === true) {
      shopPatch.licenseVerified = false;
      shopPatch.isPublic = false;
      clearLinkId = normalizeLicense(shop.licenseNumber);
    }
  } else if (type === "licenseNumber") {
    const next = text(request.newValue);
    if (!next) {
      return {error: "沒有新的特寵字號"};
    }
    if (shop.licenseVerified === true) {
      clearLinkId = normalizeLicense(shop.licenseNumber);
    }
    shopPatch.licenseNumber = next;
    shopPatch.normalizedLicenseNumber = normalizeLicense(next);
    shopPatch.licenseVerified = false;
    shopPatch.isPublic = false;
  } else if (type === "name" || type === "phone" || type === "taxId" ||
      type === "lineUrl" || type === "igUrl" || type === "fbUrl") {
    const next = text(request.newValue);
    if (!next) {
      return {error: "沒有要更新的新資料"};
    }
    shopPatch[type] = next;
    if (type === "phone") {
      shopPatch.phoneSetupCompleted = true;
    }
    if (type === "taxId") {
      shopPatch.taxIdVerified = false;
      shopPatch.isPublic = false;
    }
  } else {
    return {error: "這個申請類型不能由此功能核准"};
  }
  return {
    error: "",
    requestPatch: {
      status: "approved",
      reviewNote: note || "平台已核准並更新資料",
      reviewedBy: input.actorUid || "",
    },
    shopPatch: shopPatch,
    linkPatch: null,
    clearLinkId: clearLinkId,
  };
}

module.exports = {
  snapshotMatchesShop,
  planCertificationSubmit,
  addressResultFor,
  buildReviewPlan,
};
