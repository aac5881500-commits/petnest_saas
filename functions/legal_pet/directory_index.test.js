// 檔案名稱：functions/legal_pet/directory_index.test.js
// 功能說明：業者資料庫搜尋片段、分類篩選、同步不覆蓋聯繫的規則測試。

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {describeBusItem} = require("./codes");
const {planSync} = require("./sync_policy");
const {
  GOVERNMENT_PATCH_KEYS,
  buildNameGrams,
  planDirectorySearch,
  primaryConstraint,
  governmentDirectoryPatch,
  matchesDirectoryFilters,
  parseDirectoryDistrict,
  formatTaipeiDateTime,
  presentSync,
  listOutcome,
  planDirectoryWrite,
  readDirectoryFilters,
  directoryQuerySpec,
  executeDirectoryQuery,
  buildBackfillPatch,
  directoryFieldsCurrent,
  filterRequiresBackfill,
  scanDirectoryRecords,
  DIRECTORY_VERSION,
} = require("./directory_index");

const bothAnimals = {
  legalname: "幸福寵物之家",
  animaltype: "貓、狗",
  hasCat: true,
  hasDog: true,
  busitem: "ABC",
  busitemConfirmed: true,
  hasBreeding: true,
  hasSale: true,
  hasBoarding: true,
  businessState: "operating",
  stateFlag: "N",
  stateConfirmed: true,
  linkStatus: "candidate",
  candidateCount: 2,
  contactStatus: "follow_up",
  contactPhoneDigits: "0912345678",
  normalizedLicense: "特寵業字第A1號",
  nameNorm: "幸福寵物之家",
  countyCode: "A020",
  districtKey: "A020|三芝區",
  districtPending: false,
  validDate: "2027-01-21",
  validDateConfirmed: true,
  legaladdress: "新北市三芝區公正街1號",
};

describe("名稱中間片段", () => {
  it("索引包含名稱中段，查詢不是只取前綴", () => {
    const grams = buildNameGrams("幸福寵物之家");
    assert.equal(grams.indexOf("寵物") >= 0, true);
    assert.equal(grams.indexOf("寵物之") >= 0, true);
    const plan = planDirectorySearch("寵物之家");
    assert.equal(plan.kind, "name");
    assert.equal(plan.op, "array-contains");
    assert.equal(plan.field, "nameGrams");
    assert.equal(plan.gram, "寵物之家");
    assert.equal(grams.indexOf(plan.gram) >= 0, true);
    const longer = planDirectorySearch("幸福寵物之家");
    assert.equal(longer.gram.indexOf("幸福") === 0, false);
    assert.equal(grams.indexOf(longer.gram) >= 0, true);
    const primary = primaryConstraint(plan, {});
    assert.equal(primary.op, "array-contains");
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {},
        plan,
        "2026-10-06",
    ), true);
  });

  it("完整字號與正規化字號是同一筆精確查詢", () => {
    const spaced = planDirectorySearch("特寵業字第 A1 號");
    const folded = planDirectorySearch("特寵業字第ａ1號");
    assert.equal(spaced.kind, "license");
    assert.equal(spaced.op, "array-contains");
    assert.equal(spaced.prefix, "A1");
    assert.equal(spaced.exactNormalized, "特寵業字第A1號");
    assert.equal(folded.prefix, spaced.prefix);
    assert.equal(folded.exactNormalized, spaced.exactNormalized);
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {},
        spaced,
        "2026-10-06",
    ), true);
  });

  it("上方搜尋不把電話當條件，數字字號走完整字號", () => {
    const plan = planDirectorySearch("0912-345-678");
    assert.notEqual(plan.kind, "phone");
    assert.notEqual(plan.field, "contactPhoneDigits");
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {},
        plan,
        "2026-10-06",
    ), false);
    const digits = planDirectorySearch("0912345678");
    assert.equal(digits.kind, "name");
    assert.notEqual(digits.field, "contactPhoneDigits");
    const letters = planDirectorySearch("a12b");
    assert.equal(letters.kind, "license");
    assert.equal(letters.prefix, "A12B");
  });
});

describe("分類不會漏掉複合項目", () => {
  it("貓狗皆有同時符合含貓與含狗，複合營業項目三項都在", () => {
    const today = "2026-10-06";
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {animal: "cat"},
        {kind: "none"},
        today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {animal: "dog"},
        {kind: "none"},
        today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {animal: "both"},
        {kind: "none"},
        today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        Object.assign({}, bothAnimals, {animaltype: "貓", hasDog: false}),
        {animal: "both"},
        {kind: "none"},
        today,
    ), false);
    const bus = describeBusItem("ABC");
    assert.equal(bus.hasBreeding, true);
    assert.equal(bus.hasSale, true);
    assert.equal(bus.hasBoarding, true);
    const unknown = describeBusItem("Z");
    assert.equal(unknown.hasBoarding, false);
    assert.equal(unknown.confirmed, false);
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {bus: "boarding", businessState: "operating"},
        {kind: "none"},
        today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {linkStatus: "candidate", contactStatus: "follow_up"},
        {kind: "none"},
        today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        bothAnimals,
        {linkStatus: "none"},
        {kind: "none"},
        today,
    ), false);
  });

  it("基隆市可解析，對不上的地址維持區域待確認", () => {
    const keelung = parseDirectoryDistrict("基隆市仁愛區愛一路1號", "A030");
    assert.equal(keelung.districtPending, false);
    assert.equal(keelung.districtLabel, "仁愛區");
    const pending = parseDirectoryDistrict("某某路1號", "A020");
    assert.equal(pending.districtPending, true);
    assert.equal(pending.districtLabel, "");
    const patch = governmentDirectoryPatch({
      legalname: "幸福寵物之家",
      legaladdress: "某某路1號",
      countyCode: "A020",
      busitem: "AC",
      animaltype: "犬",
      stateFlag: "N",
      stateConfirmed: true,
      validDate: "",
      validDateConfirmed: false,
    }, "2026-10-06");
    assert.equal(patch.hasCat, false);
    assert.equal(patch.hasDog, false);
    assert.equal(patch.hasBoarding, true);
    assert.equal(patch.hasBreeding, true);
    assert.equal(patch.hasSale, false);
    assert.equal(patch.districtPending, true);
    assert.equal(patch.businessState, "operating");
    assert.equal(patch.validity, "unknown");
  });
});

describe("同步與查詢狀態", () => {
  it("政府目錄更新不包含人工聯繫欄位", () => {
    ["contactStatus", "contactPhoneDigits", "phone", "note", "website",
      "linkStatus", "candidateCount"].forEach((key) => {
      assert.equal(GOVERNMENT_PATCH_KEYS.indexOf(key), -1);
    });
    const directory = planDirectoryWrite({
      hashMatch: true,
      version: 0,
      staleBudget: 1,
    });
    assert.equal(directory.action, "skip");
    const changed = planDirectoryWrite({hashMatch: false});
    assert.equal(changed.action, "content");
    assert.equal(directory.touchesContact, false);
    assert.equal(directory.deletes, false);
    const failed = planSync({
      error: new Error("timeout"),
      previousSuccessCount: 1000,
    });
    assert.equal(failed.commit, false);
    assert.equal(failed.touchesContacts, false);
    assert.deepEqual(failed.deletes, []);
  });

  it("失敗仍保留最後成功時間，空結果與查詢失敗分開", () => {
    const sync = presentSync({
      lastResult: "failed",
      lastSuccessAt: "2026-10-06T13:59:29.000Z",
      lastFailureAt: "2026-10-06T14:10:00.000Z",
      lastErrorSummary: "timeout",
    }, Date.parse("2026-10-06T15:00:00.000Z"));
    assert.equal(sync.phase, "failed");
    assert.equal(sync.successText, "2026/10/06 21:59");
    assert.equal(formatTaipeiDateTime("2026-10-06T13:59:29.000Z"),
        "2026/10/06 21:59");
    assert.equal(listOutcome({error: true, itemCount: 0}), "query_failed");
    assert.equal(listOutcome({
      phase: "success",
      itemCount: 0,
      hasMore: false,
    }), "empty");
    assert.equal(listOutcome({
      phase: "never",
      itemCount: 0,
    }), "not_synced");
    assert.equal(listOutcome({needsBackfill: true, itemCount: 0}),
        "needs_backfill");
  });

  it("換篩選會回到沒有游標的第一頁條件", () => {
    const filters = readDirectoryFilters({
      countyCode: "A020",
      district: "三芝區",
      animal: "cat",
      bus: "boarding",
      linkStatus: "none",
      contactStatus: "follow_up",
    });
    assert.equal(filters.districtKey, "A020|三芝區");
    assert.equal(filters.animal, "cat");
    assert.equal(filters.bus, "boarding");
    assert.equal(filters.linkStatus, "none");
    assert.equal(filters.contactStatus, "follow_up");
  });
});

describe("店名只比對 legalname", () => {
  const today = "2026-10-06";

  it("單字貓只符合店名，不因寵物種類列入", () => {
    const plan = planDirectorySearch("貓");
    assert.equal(plan.kind, "name");
    assert.equal(plan.gram, "貓");
    assert.equal(plan.needle, "貓");
    const named = {
      legalname: "貓邊寵物",
      animaltype: "狗",
      nameGrams: buildNameGrams("貓邊寵物"),
    };
    const animalOnly = {
      legalname: "宜鴻商行",
      animaltype: "貓",
      hasCat: true,
      nameGrams: buildNameGrams("宜鴻商行"),
    };
    assert.equal(named.nameGrams.indexOf("貓") >= 0, true);
    assert.equal(animalOnly.nameGrams.indexOf("貓"), -1);
    assert.equal(matchesDirectoryFilters(named, {}, plan, today), true);
    assert.equal(matchesDirectoryFilters(animalOnly, {}, plan, today), false);
  });

  it("名稱中間單字與連續片段要比對完整內容", () => {
    const grams = buildNameGrams("幸福寵物之家");
    assert.equal(grams.indexOf("寵") >= 0, true);
    assert.equal(grams.indexOf("物") >= 0, true);
    const middle = planDirectorySearch("邊");
    const shop = {legalname: "貓邊寵物"};
    assert.equal(matchesDirectoryFilters(shop, {}, middle, today), true);
    const fragment = planDirectorySearch("貓邊");
    assert.equal(fragment.gram, "貓邊");
    assert.equal(matchesDirectoryFilters(shop, {}, fragment, today), true);
    assert.equal(matchesDirectoryFilters(
        {legalname: "邊貓寵物"},
        {},
        fragment,
        today,
    ), false);
  });

  it("搜尋與篩選要同時成立", () => {
    const name = planDirectorySearch("貓");
    const catAndDog = {
      legalname: "貓店",
      animaltype: "狗",
      busitem: "C",
    };
    assert.equal(matchesDirectoryFilters(
        catAndDog,
        {animal: "dog"},
        name,
        today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        catAndDog,
        {bus: "boarding"},
        name,
        today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        {legalname: "貓店", animaltype: "貓", busitem: "B"},
        {bus: "boarding"},
        name,
        today,
    ), false);
    assert.equal(matchesDirectoryFilters(
        {legalname: "狗店", animaltype: "狗", busitem: "C"},
        {bus: "boarding"},
        name,
        today,
    ), false);
  });
});

describe("快篩條件", () => {
  const today = "2026-10-06";

  it("貓狗皆有排除只有貓或只有狗", () => {
    const both = {animaltype: "貓、狗"};
    const catOnly = {animaltype: "貓"};
    const dogOnly = {animaltype: "狗"};
    assert.equal(matchesDirectoryFilters(
        both, {animal: "both"}, {kind: "none"}, today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        catOnly, {animal: "both"}, {kind: "none"}, today,
    ), false);
    assert.equal(matchesDirectoryFilters(
        dogOnly, {animal: "both"}, {kind: "none"}, today,
    ), false);
    assert.equal(matchesDirectoryFilters(
        both, {animal: "cat"}, {kind: "none"}, today,
    ), true);
  });

  it("沒有認證綁定時已認證快篩是零筆", () => {
    const records = [
      {govSort: "001", linkStatus: "none", legalname: "甲"},
      {govSort: "002", linkStatus: "candidate", legalname: "乙"},
      {govSort: "003", legalname: "丙"},
    ];
    const page = scanDirectoryRecords(records, {
      filters: {linkStatus: "certified"},
      search: {kind: "none"},
      today: today,
    });
    assert.equal(page.items.length, 0);
    assert.equal(page.hasMore, false);
    assert.equal(filterRequiresBackfill(
        {kind: "none"},
        {linkStatus: "certified"},
        false,
    ), false);
    assert.deepEqual(
        primaryConstraint({kind: "none"}, {linkStatus: "certified"}, false),
        {field: "linkStatus", op: "eq", value: "certified"},
    );
  });

  it("待跟進只列 follow_up", () => {
    const filters = {contactStatus: "follow_up"};
    assert.equal(matchesDirectoryFilters(
        {contactStatus: "follow_up"}, filters, {kind: "none"}, today,
    ), true);
    assert.equal(matchesDirectoryFilters(
        {contactStatus: "contacted"}, filters, {kind: "none"}, today,
    ), false);
    assert.equal(matchesDirectoryFilters(
        {}, filters, {kind: "none"}, today,
    ), false);
  });
});

describe("分頁與補齊", () => {
  const today = "2026-10-06";

  it("搜尋可以找到後面才符合的業者，空批不宣告結束", () => {
    const records = [];
    for (let index = 1; index <= 12; index += 1) {
      records.push({
        govSort: String(index).padStart(3, "0"),
        legalname: "其他商行",
      });
    }
    records.push({govSort: "013", legalname: "後面的貓店"});
    const search = planDirectorySearch("貓");
    const missed = scanDirectoryRecords(records, {
      search: search,
      filters: {},
      pageSize: 30,
      scanLimit: 5,
      today: today,
    });
    assert.equal(missed.items.length, 0);
    assert.equal(missed.hasMore, true);
    assert.equal(listOutcome({
      phase: "success",
      itemCount: missed.items.length,
      hasMore: missed.hasMore,
    }), "continue");
    const found = scanDirectoryRecords(records, {
      search: search,
      filters: {},
      cursor: missed.nextCursor,
      pageSize: 30,
      scanLimit: 20,
      today: today,
    });
    assert.equal(found.items.length, 1);
    assert.equal(found.items[0].legalname, "後面的貓店");
  });

  it("鼓山區地址可解析，縣市矛盾才待確認", () => {
    const place = parseDirectoryDistrict(
        "高雄市鼓山區中華一路2220號",
        "A040",
    );
    assert.equal(place.districtLabel, "鼓山區");
    assert.equal(place.districtKey, "A040|鼓山區");
    assert.equal(place.districtPending, false);
    const spaced = parseDirectoryDistrict(
        "高雄市 鼓山區 中華一路2220號",
        "A040",
    );
    assert.equal(spaced.districtPending, false);
    assert.equal(spaced.districtLabel, "鼓山區");
    const folded = parseDirectoryDistrict("台中市西區台灣大道1號", "A060");
    assert.equal(folded.districtLabel, "西區");
    assert.equal(folded.districtPending, false);
    const conflict = parseDirectoryDistrict(
        "高雄市鼓山區中華一路2220號",
        "A010",
    );
    assert.equal(conflict.districtPending, true);
    assert.equal(conflict.districtLabel, "");
  });

  it("既有文件可補單字索引與區域，且不覆蓋人工聯繫", () => {
    const row = {
      legalname: "鼓山寵物",
      legaladdress: "高雄市鼓山區中華一路2220號",
      countyCode: "A040",
      directoryVersion: 1,
      nameGrams: ["鼓山", "山寵"],
      contactStatus: "follow_up",
      note: "人工備註",
      website: "https://keep.example",
      phone: "07-0000000",
      linkStatus: "certified",
      stateFlag: "N",
      stateConfirmed: true,
      animaltype: "貓",
      busitem: "C",
      validDate: "2027-01-01",
      validDateConfirmed: true,
    };
    const untouched = buildBackfillPatch(row, null, null, today);
    assert.equal(untouched.directoryVersion, DIRECTORY_VERSION);
    assert.equal(untouched.nameGrams.indexOf("鼓") >= 0, true);
    assert.equal(untouched.districtLabel, "鼓山區");
    assert.equal(untouched.districtPending, false);
    assert.equal(untouched.note, undefined);
    assert.equal(untouched.website, undefined);
    assert.equal(untouched.phone, undefined);
    assert.equal(untouched.contactStatus, undefined);
    assert.equal(untouched.linkStatus, undefined);
    assert.equal(directoryFieldsCurrent(row, untouched), false);
    const mirrored = buildBackfillPatch(row, {
      contactStatus: "follow_up",
      phone: "0912-111-222",
      note: "不要寫回政府文件",
      website: "https://staff.example",
    }, {
      certifiedShopId: "shop-1",
      candidateShopIds: [],
    }, today);
    assert.equal(mirrored.contactStatus, "follow_up");
    assert.equal(mirrored.linkStatus, "certified");
    assert.equal(mirrored.note, undefined);
    assert.equal(mirrored.website, undefined);
    assert.equal(mirrored.phone, undefined);
    const government = governmentDirectoryPatch(row, today);
    assert.equal(government.contactStatus, undefined);
    assert.equal(government.note, undefined);
    const write = planDirectoryWrite({
      hashMatch: true,
      version: 1,
      staleBudget: 1,
    });
    assert.equal(write.action, "skip");
    assert.equal(write.touchesContact, false);
    assert.equal(write.deletes, false);
    assert.equal(filterRequiresBackfill(
        planDirectorySearch("鼓"),
        {},
        false,
    ), true);
  });
});

/**
 * @param {Object} fields 覆蓋欄位
 * @return {Object}
 */
function indexedShop(fields) {
  const row = Object.assign({
    govSort: "00000001",
    legalname: "宜鴻商行",
    normalizedLicense: "特寵業字第W1070151號",
    validnum: "特寵業字第W1070151號",
    animaltype: "狗",
    stateFlag: "N",
    stateConfirmed: true,
    validDate: "2027-01-01",
    validDateConfirmed: true,
    countyCode: "A040",
    legaladdress: "高雄市鼓山區中華一路2220號",
  }, fields || {});
  return Object.assign({}, row, governmentDirectoryPatch(row, "2026-10-08"));
}

describe("店名與字號索引查詢", () => {
  const today = "2026-10-08";

  it("完整店名、單字與中間片段都走名稱索引", () => {
    const shop = indexedShop();
    ["宜鴻商行", "宜", "鴻", "宜鴻", "商行"].forEach((word) => {
      const search = planDirectorySearch(word);
      assert.equal(search.kind, "name");
      assert.equal(search.field, "nameGrams");
      const spec = directoryQuerySpec(search, {}, true);
      assert.equal(spec.constraint.op, "array-contains");
      assert.equal(spec.constraint.field, "nameGrams");
      assert.equal(spec.orderBy, "govSort");
      const page = executeDirectoryQuery([shop], spec, {
        search: search,
        filters: {},
        today: today,
      });
      assert.equal(page.items.length, 1);
      assert.equal(page.items[0].legalname, "宜鴻商行");
    });
  });

  it("單搜貓只命中店名，英文店名不會被當成字號", () => {
    const catName = indexedShop({
      govSort: "00000002",
      legalname: "貓邊寵物",
      animaltype: "狗",
    });
    const catTypeOnly = indexedShop({
      govSort: "00000003",
      legalname: "宜鴻商行",
      animaltype: "貓",
    });
    const english = indexedShop({
      govSort: "00000004",
      legalname: "PET HOUSE",
    });
    const search = planDirectorySearch("貓");
    const spec = directoryQuerySpec(search, {}, true);
    const page = executeDirectoryQuery(
        [catName, catTypeOnly, english],
        spec,
        {search: search, filters: {}, today: today},
    );
    assert.equal(page.items.length, 1);
    assert.equal(page.items[0].legalname, "貓邊寵物");
    assert.equal(page.candidateReads, 1);
    const pet = planDirectorySearch("PET");
    assert.equal(pet.kind, "name");
    assert.equal(planDirectorySearch("PET HOUSE").kind, "name");
  });

  it("W 與 V 前綴、短字號和政府包裝文字查同一套索引", () => {
    const shop = indexedShop();
    const other = indexedShop({
      govSort: "00000009",
      legalname: "另一商行",
      normalizedLicense: "特寵業字第V2000001號",
      validnum: "特寵業字第V2000001號",
    });
    ["W", "w", "Ｗ", "W107", "W1070151", "特寵業字第W1070151號"].forEach((word) => {
      const search = planDirectorySearch(word);
      assert.equal(search.kind, "license");
      assert.equal(search.field, "licensePrefixes");
      const spec = directoryQuerySpec(search, {}, true);
      assert.equal(spec.constraint.op, "array-contains");
      assert.notEqual(spec.constraint.field, "normalizedLicense");
      const page = executeDirectoryQuery([shop, other], spec, {
        search: search,
        filters: {},
        today: today,
      });
      assert.equal(page.items.length, 1);
      assert.equal(page.items[0].govSort, "00000001");
    });
    const onlyV = planDirectorySearch("V");
    const vPage = executeDirectoryQuery(
        [shop, other],
        directoryQuerySpec(onlyV, {}, true),
        {search: onlyV, filters: {}, today: today},
    );
    assert.equal(vPage.items.length, 1);
    assert.equal(vPage.items[0].govSort, "00000009");
    assert.equal(filterRequiresBackfill(onlyV, {}, false), true);
  });

  it("店名與寵物篩選同時成立，空批不會宣告結束", () => {
    const namedDog = indexedShop({animaltype: "狗"});
    const namedCat = indexedShop({
      govSort: "00000002",
      animaltype: "貓",
    });
    const search = planDirectorySearch("宜鴻");
    const filters = {animal: "dog"};
    const spec = directoryQuerySpec(search, filters, true);
    assert.equal(spec.constraint.field, "nameGrams");
    const page = executeDirectoryQuery([namedDog, namedCat], spec, {
      search: search,
      filters: filters,
      today: today,
    });
    assert.equal(page.items.length, 1);
    assert.equal(page.items[0].animaltype, "狗");
    const later = [];
    for (let index = 1; index <= 5; index += 1) {
      later.push(indexedShop({
        govSort: String(index).padStart(8, "0"),
        legalname: "宜鴻分店" + index,
        animaltype: "貓",
      }));
    }
    later.push(indexedShop({
      govSort: "00000020",
      legalname: "後面宜鴻",
      animaltype: "狗",
    }));
    const broad = planDirectorySearch("宜鴻");
    const dogOnly = {animal: "dog"};
    const missed = executeDirectoryQuery(
        later,
        directoryQuerySpec(broad, dogOnly, true),
        {
          search: broad,
          filters: dogOnly,
          today: today,
          scanLimit: 3,
        },
    );
    assert.equal(missed.items.length, 0);
    assert.equal(missed.hasMore, true);
    assert.equal(missed.candidateReads, 3);
    const found = executeDirectoryQuery(
        later,
        directoryQuerySpec(broad, dogOnly, true),
        {
          search: broad,
          filters: dogOnly,
          today: today,
          cursor: missed.nextCursor,
          scanLimit: 10,
        },
    );
    assert.equal(found.items.length, 1);
    assert.equal(found.items[0].legalname, "後面宜鴻");
    assert.equal(listOutcome({
      phase: "success",
      itemCount: 0,
      hasMore: true,
    }), "continue");
  });

  it("來源未變但日期已過，顯示已過期", () => {
    const row = indexedShop({
      validDate: "2026-10-01",
      validDateConfirmed: true,
      validity: "valid",
    });
    const patched = governmentDirectoryPatch(row, "2026-10-08");
    assert.equal(patched.validity, "expired");
    assert.equal(matchesDirectoryFilters(
        Object.assign({}, row, {validity: "valid"}),
        {validity: "valid"},
        {kind: "none"},
        "2026-10-08",
    ), false);
  });
});
