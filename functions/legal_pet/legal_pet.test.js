// 檔案名稱：functions/legal_pet/legal_pet.test.js
// 功能說明：字號查核、地址鎖定、認證審核、重複綁定與政府同步失敗的規則測試。

const fs = require("fs");
const path = require("path");
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeLicense,
  parseSourceDate,
  taipeiDateKey,
  parseGovernmentAddress,
  compareAddress,
  buildGovernmentRecord,
  classifyLookup,
} = require("./normalize");
const {
  isAddressLocked,
  isPhoneLocked,
  buildInitialProfilePlan,
  guardShopCertification,
} = require("./profile_lock");
const {planSync} = require("./sync_policy");
const {buildReviewPlan, planCertificationSubmit} = require("./review_policy");
const {canReviewShopRequests, canViewDirectory} = require("./access");

const shop = {
  shopId: "S1",
  name: "毛耳朵",
  city: "新北市",
  district: "三芝區",
  address: "公正街25號1樓",
  licenseNumber: "特寵業繁字第A1100892號",
  taxId: "12345678",
  licenseVerified: false,
  taxIdVerified: false,
};

describe("首次地址與電話鎖定", () => {
  it("地址空白時可套用並在計畫中鎖定，不改店名與統編", () => {
    const plan = buildInitialProfilePlan({
      shop: {address: "", city: "新竹縣", district: "新埔鎮", phone: ""},
      city: "新北市",
      district: "三芝區",
      address: "公正街25號1樓",
    });
    assert.equal(plan.error, "");
    assert.equal(plan.patch.addressSetupCompleted, true);
    assert.equal(plan.patch.city, "新北市");
    assert.equal(plan.patch.name, undefined);
    assert.equal(plan.patch.taxId, undefined);
    assert.equal(plan.patch.licenseVerified, undefined);
  });

  it("已有地址的既有店家不能直接覆蓋", () => {
    assert.equal(isAddressLocked({address: "公正街1號", phone: ""}), true);
    assert.equal(isPhoneLocked({address: "公正街1號", phone: ""}), false);
    const plan = buildInitialProfilePlan({
      shop: {address: "公正街1號", city: "新北市", district: "三芝區"},
      city: "新北市",
      district: "三芝區",
      address: "政府路2號",
    });
    assert.ok(plan.error.indexOf("修改申請") >= 0);
  });

  it("電話空白不會把已填地址再解開", () => {
    assert.equal(isAddressLocked({
      address: "公正街1號",
      phone: "",
      licenseVerified: false,
    }), true);
  });

  it("尚未認證不是首次設定", () => {
    assert.equal(isAddressLocked({
      address: "公正街1號",
      licenseVerified: false,
      addressSetupCompleted: false,
    }), true);
  });
});

describe("政府查核狀態", () => {
  it("正規化空白與全形，但保留繁字", () => {
    const breeding = normalizeLicense("特寵業繁字第 ａ1100892 號");
    const normal = normalizeLicense("特寵業字第A1100892號");
    assert.equal(breeding, "特寵業繁字第A1100892號");
    assert.notEqual(breeding, normal);
  });

  it("純日期不因 UTC 偏移", () => {
    assert.deepEqual(parseSourceDate("2027-01-21T00:00:00"), {
      date: "2027-01-21",
      confirmed: true,
    });
    assert.deepEqual(parseSourceDate("2021/11/30 上午 12:00:00"), {
      date: "2021-11-30",
      confirmed: true,
    });
    assert.equal(
        taipeiDateKey(new Date("2026-10-06T16:30:00Z")),
        "2026-10-07",
    );
  });

  it("查無、來源失敗、過期與多筆分開", () => {
    const fresh = new Date().toISOString();
    assert.equal(classifyLookup({
      sync: {lastSuccessAt: fresh},
      matchCount: 0,
      nowMs: Date.now(),
    }), "none");
    assert.equal(classifyLookup({
      sync: {},
      matchCount: 0,
      nowMs: Date.now(),
    }), "unavailable");
    assert.equal(classifyLookup({
      sync: {lastSuccessAt: "2020-01-01T00:00:00.000Z"},
      matchCount: 0,
      nowMs: Date.now(),
    }), "stale");
    assert.equal(classifyLookup({
      sync: {lastSuccessAt: fresh},
      matchCount: 1,
      licenseStatus: "expired",
      nowMs: Date.now(),
    }), "expired");
    assert.equal(classifyLookup({
      sync: {lastSuccessAt: fresh},
      matchCount: 2,
      nowMs: Date.now(),
    }), "multiple");
  });

  it("未知商家狀態不判成營業中", () => {
    const record = buildGovernmentRecord({
      ID: "9",
      legaltype: "A020",
      legalname: "測試",
      legaladdress: "新北市三芝區公正街25號1樓",
      busitem: "Z",
      animaltype: "貓",
      validnum: "特寵業字第A1號",
      validdate: "2027-01-21T00:00:00",
      state_flag: "Z",
    }, "2026-10-06");
    assert.equal(record.stateConfirmed, false);
    assert.match(record.stateLabel, /待確認/);
    assert.equal(record.licenseStatus, "unknown");
    assert.equal(record.busitemConfirmed, false);
  });

  it("官方代碼可解釋營業項目與廢止", () => {
    const record = buildGovernmentRecord({
      ID: "10",
      legaltype: "A020",
      busitem: "ABC",
      state_flag: "B",
      validnum: "特寵業字第A1號",
      validdate: "2027-01-21T00:00:00",
      animaltype: "貓",
    }, "2026-10-06");
    assert.equal(record.busitemLabel, "繁殖、買賣、寄養");
    assert.equal(record.stateLabel, "廢止");
    assert.equal(record.hasBoarding, true);
    assert.equal(record.licenseStatus, "revoked");
  });
});

describe("地址比對", () => {
  it("台臺與空白可相符，門牌不同則是明顯差異", () => {
    assert.equal(compareAddress({
      city: "台北市",
      district: "大安區",
      address: "復興南路1號",
    }, "臺北市大安區復興南路1號", "A010").result, "match");
    assert.equal(compareAddress({
      city: "台北市",
      district: "大安區",
      address: "復興南路1號",
    }, "臺北市大安區復興南路2號", "A010").result, "mismatch");
  });

  it("路段差異不能忽略，無法判斷時標示人工確認", () => {
    assert.equal(compareAddress({
      city: "台北市",
      district: "大安區",
      address: "復興南路一段1號",
    }, "臺北市大安區復興南路1號", "A010").result, "mismatch");
    assert.equal(compareAddress({
      city: "新北市",
      district: "三芝區",
      address: "公正街1號",
    }, "", "A020").result, "manual");
  });

  it("基隆市不在 App 縣市清單時不猜測套用", () => {
    const parsed = parseGovernmentAddress("基隆市暖暖區某路1號", "A030");
    assert.equal(parsed.reliable, false);
  });

  it("可靠地址可拆出縣市區域與詳細地址", () => {
    const parsed = parseGovernmentAddress(
        "新北市三芝區公正街25號1樓",
        "A020",
    );
    assert.equal(parsed.reliable, true);
    assert.equal(parsed.city, "新北市");
    assert.equal(parsed.district, "三芝區");
    assert.equal(parsed.detail, "公正街25號1樓");
  });
});

describe("認證送件與同時核准", () => {
  it("查無或來源失敗仍可送人工補審", () => {
    assert.equal(planCertificationSubmit({
      checkResult: "none",
      addressComparison: "unavailable",
    }).error, "");
    assert.equal(planCertificationSubmit({
      checkResult: "unavailable",
      addressComparison: "manual",
    }).error, "");
  });

  it("明顯差異沒有說明與證明不能送審", () => {
    const plan = planCertificationSubmit({
      checkResult: "matched",
      addressComparison: "mismatch",
      addressDifferenceNote: "",
      addressProofImageUrl: "",
    });
    assert.match(plan.error, /差異說明/);
  });

  it("字號變更後不能沿用舊認證", () => {
    const decision = guardShopCertification({
      licenseNumber: "特寵業字第A1號",
      licenseVerified: true,
      city: "新北市",
      district: "三芝區",
      address: "公正街1號",
    }, {
      licenseNumber: "特寵業字第B2號",
      licenseVerified: true,
      city: "新北市",
      district: "三芝區",
      address: "公正街1號",
    });
    assert.equal(decision.clearLicense, true);
  });

  it("同一筆核准同時改地址時，新認證留在新地址上", () => {
    const decision = guardShopCertification({
      licenseNumber: "特寵業字第A1號",
      licenseVerified: true,
      city: "新北市",
      district: "三芝區",
      address: "舊地址1號",
      licenseCertifiedAt: 1,
    }, {
      licenseNumber: "特寵業字第A1號",
      licenseVerified: true,
      city: "新北市",
      district: "三芝區",
      address: "公正街1號",
      licenseCertifiedAt: 2,
    });
    assert.equal(decision.clearLicense, false);
  });

  it("送件後正式地址已變就不能核准舊資料", () => {
    const plan = buildReviewPlan({
      action: "approve",
      approveLicense: true,
      actorUid: "reviewer",
      shop: shop,
      shopId: "S1",
      request: {
        status: "pending",
        requestType: "fullVerify",
        shopSnapshot: Object.assign({}, shop, {address: "舊地址1號"}),
      },
    });
    assert.match(plan.error, /重新查核/);
  });

  it("其他店家已綁定時不能靜默覆蓋", () => {
    const blocked = buildReviewPlan({
      action: "approve",
      approveLicense: true,
      shop: shop,
      shopId: "S1",
      link: {certifiedShopId: "S2"},
      request: {
        status: "pending",
        requestType: "fullVerify",
        shopSnapshot: shop,
      },
    });
    assert.match(blocked.error, /不能直接覆蓋/);
    const transferred = buildReviewPlan({
      action: "approve",
      approveLicense: true,
      transferLicense: true,
      shop: shop,
      shopId: "S1",
      link: {certifiedShopId: "S2"},
      request: {
        status: "pending",
        requestType: "fullVerify",
        shopSnapshot: shop,
      },
    });
    assert.equal(transferred.error, "");
    assert.equal(transferred.previousShopPatch.licenseVerified, false);
    assert.equal(transferred.linkPatch.certifiedShopId, "S1");
  });

  it("查到字號也不把統編標成已認證", () => {
    const plan = buildReviewPlan({
      action: "approve",
      approveLicense: true,
      approveTaxId: false,
      shop: shop,
      shopId: "S1",
      link: {},
      request: {
        status: "pending",
        requestType: "fullVerify",
        shopSnapshot: shop,
      },
    });
    assert.equal(plan.error, "");
    assert.equal(plan.shopPatch.licenseVerified, true);
    assert.equal(plan.shopPatch.taxIdVerified, undefined);
  });
});

describe("同步失敗與權限", () => {
  it("下載失敗不清空、不刪除、不碰聯繫紀錄", () => {
    const plan = planSync({
      error: new Error("timeout"),
      previousSuccessCount: 1000,
    });
    assert.equal(plan.commit, false);
    assert.deepEqual(plan.deletes, []);
    assert.equal(plan.touchesContacts, false);
  });

  it("筆數異常時不提交", () => {
    const rows = [{ID: "1"}];
    const plan = planSync({rows: rows, previousSuccessCount: 1000});
    assert.equal(plan.commit, false);
  });

  it("非平台帳號不能審核或查看名單", () => {
    const outsider = {uid: "user", enabled: true, permissions: []};
    assert.equal(canReviewShopRequests(outsider), false);
    assert.equal(canViewDirectory(outsider), false);
    const viewer = {uid: "staff", enabled: true, permissions: ["view_shops"]};
    assert.equal(canViewDirectory(viewer), true);
    assert.equal(canReviewShopRequests(viewer), false);
  });

  it("規則不讓店家改認證或綁定", () => {
    const rules = fs.readFileSync(
        path.join(__dirname, "../../firestore.rules"),
        "utf8",
    );
    assert.match(rules, /legal_pet_businesses/);
    assert.match(rules, /legal_pet_license_links\/\{linkId\}/);
    const linkBlock = rules.split("match /legal_pet_license_links/")[1]
        .split("match /")[0];
    assert.match(linkBlock, /allow write: if false/);
    const shops = rules.split("match /shops/{shopId}")[1]
        .split("match /shop_members")[0];
    assert.match(shops, /shopSensitiveProfileUnchanged\(\)/);
    assert.equal(shops.indexOf("'licenseVerified'"), -1);
    assert.equal(shops.indexOf("'taxIdVerified'"), -1);
  });
});
