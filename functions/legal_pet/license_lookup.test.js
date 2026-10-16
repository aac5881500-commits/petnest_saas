const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeLicense,
  parseLicenseLookup,
  buildGovernmentRecord,
  licenseLookupFields,
  licenseLookupCurrent,
  selectLicenseLookupWrites,
  planLookupBackfillResult,
  lookupStatusFor,
  chooseGovernmentRecord,
  licenseCoreQueryToken,
  selectExactLicenseRecords,
  LOOKUP_KEY_VERSION,
} = require("./normalize");
const {planDirectorySearch} = require("./directory_index");
const {
  LOOKUP_MESSAGES,
  LICENSE_LOOKUP_LIMIT,
  lookupFailureResult,
  publicMatch,
  queryByLookupKey,
} = require("./shop_operations");

const fresh = new Date().toISOString();

test("一般前綴的各種寫法得到同一個查核鍵", () => {
  const samples = [
    "W1070485",
    "w1070485",
    "Ｗ１０７０４８５",
    "W1070485號",
    "特寵業字第Ｗ1070485號",
    "  特寵業字第 W1070485 號  ",
  ];
  samples.forEach((sample) => {
    const parsed = parseLicenseLookup(sample);
    assert.equal(parsed.ok, true, sample);
    assert.equal(parsed.kind, "standard", sample);
    assert.equal(parsed.key, "W1070485", sample);
  });
});

test("尾碼不同不能併成同一證照", () => {
  const first = parseLicenseLookup("V1140460-00");
  const second = parseLicenseLookup("V1140460-01");
  assert.equal(first.key, "V1140460-00");
  assert.equal(second.key, "V1140460-01");
  assert.notEqual(first.key, second.key);
  assert.equal(parseLicenseLookup("特寵業字第V1140460-00號").key, "V1140460-00");
});

test("不完整、任意文字與不明前綴不能查核", () => {
  ["W107", "1070485", "你好", "特寵業其他字第W1070485號", ""].forEach(
      (sample) => {
        const parsed = parseLicenseLookup(sample);
        assert.equal(parsed.ok, false, sample);
        assert.equal(parsed.key, "", sample);
      },
  );
  assert.equal(
      parseLicenseLookup("特寵業其他字第W1070485號").kind,
      "unrecognized",
  );
});

test("繁字保留區別，也不改既有綁定字號", () => {
  const breeding = parseLicenseLookup("特寵業繁字第 ａ1100892 號");
  const normal = parseLicenseLookup("特寵業字第A1100892號");
  assert.equal(breeding.ok, true);
  assert.equal(breeding.kind, "breeding");
  assert.equal(breeding.key, "繁字:A1100892");
  assert.notEqual(breeding.key, normal.key);
  assert.equal(
      normalizeLicense("特寵業繁字第 ａ1100892 號"),
      "特寵業繁字第A1100892號",
  );
  assert.notEqual(
      normalizeLicense("特寵業繁字第A1100892號"),
      normalizeLicense("特寵業字第A1100892號"),
  );
});

test("多筆同鍵不自動取第一筆", () => {
  const records = [{govId: "1"}, {govId: "2"}];
  const open = chooseGovernmentRecord(records, "");
  assert.equal(open.chosen, null);
  assert.notEqual(open.chosen, records[0]);
  const picked = chooseGovernmentRecord(records, "2");
  assert.equal(picked.chosen.govId, "2");
});

test("未補齊、查無與來源失敗分開", () => {
  const missingVersion = lookupStatusFor({
    license: "W1070485",
    licenseLookupVersion: 0,
    sync: {lastSuccessAt: fresh},
    matchCount: 0,
    nowMs: Date.now(),
  });
  assert.equal(missingVersion.status, "none");
  assert.equal(missingVersion.shouldQuery, true);
  assert.equal(missingVersion.key, "W1070485");
  const foundWithoutKeyVersion = lookupStatusFor({
    license: "W1070485",
    licenseLookupVersion: 0,
    sync: {lastSuccessAt: fresh},
    matchCount: 1,
    nowMs: Date.now(),
  });
  assert.equal(foundWithoutKeyVersion.status, "matched");
  const none = lookupStatusFor({
    license: "W1070485",
    licenseLookupVersion: LOOKUP_KEY_VERSION,
    sync: {lastSuccessAt: fresh},
    matchCount: 0,
    nowMs: Date.now(),
  });
  assert.equal(none.status, "none");
  assert.equal(none.shouldQuery, true);
  const failed = lookupStatusFor({
    license: "W1070485",
    licenseLookupVersion: LOOKUP_KEY_VERSION,
    sourceFailed: true,
    sync: {lastSuccessAt: fresh},
    matchCount: 0,
    nowMs: Date.now(),
  });
  assert.equal(failed.status, "unavailable");
  const multiple = lookupStatusFor({
    license: "特寵業字第W1070485號",
    licenseLookupVersion: LOOKUP_KEY_VERSION,
    sync: {lastSuccessAt: fresh},
    matchCount: 2,
    nowMs: Date.now(),
  });
  assert.equal(multiple.status, "multiple");
  assert.equal(multiple.key, "W1070485");
});

test("舊文件補齊後可查，且不改認證與綁定欄位", () => {
  const old = {
    id: "gov-1",
    validnum: "特寵業字第Ｗ1070485號",
    normalizedLicense: "特寵業字第W1070485號",
    licenseVerified: true,
    certifiedShopId: "shop-a",
    salesRepId: "rep-1",
    contactNote: "勿覆蓋",
  };
  const first = selectLicenseLookupWrites([old]);
  assert.equal(first.skipped, 0);
  assert.equal(first.updates.length, 1);
  assert.equal(first.updates[0].patch.licenseLookupKey, "W1070485");
  assert.deepEqual(Object.keys(first.updates[0].patch).sort(), [
    "licenseLookupKey",
    "licenseLookupKind",
    "licenseLookupVersion",
  ]);
  const filled = Object.assign({}, old, first.updates[0].patch);
  const second = selectLicenseLookupWrites([filled]);
  assert.equal(second.updates.length, 0);
  assert.equal(second.skipped, 1);
  assert.equal(filled.certifiedShopId, "shop-a");
  assert.equal(filled.contactNote, "勿覆蓋");
  assert.equal(filled.normalizedLicense, "特寵業字第W1070485號");
  assert.equal(licenseLookupCurrent(filled, licenseLookupFields(filled)), true);
});

test("新同步資料帶查核鍵，原始字號與正規化字號仍保留", () => {
  const record = buildGovernmentRecord({
    ID: "15",
    legaltype: "A020",
    legalname: "測試",
    legaladdress: "新北市三芝區公正街25號1樓",
    busitem: "ABC",
    animaltype: "貓",
    validnum: "特寵業字第Ｗ1070485號",
    validdate: "2027-01-21T00:00:00",
    state_flag: "1",
  }, "2026-10-09");
  assert.equal(record.validnum, "特寵業字第Ｗ1070485號");
  assert.equal(record.normalizedLicense, "特寵業字第W1070485號");
  assert.equal(record.licenseLookupKey, "W1070485");
  assert.notEqual(record.licenseLookupKey, record.normalizedLicense);
  assert.equal(record.licenseLookupVersion, LOOKUP_KEY_VERSION);
});

test("補齊失敗不標完成，未變資料不需再寫", () => {
  const failed = planLookupBackfillResult({
    writeFailed: true,
    done: true,
    canFinish: true,
  });
  assert.equal(failed.markReady, false);
  assert.equal(failed.saveCursor, false);
  const midway = planLookupBackfillResult({
    writeFailed: false,
    done: false,
    canFinish: true,
  });
  assert.equal(midway.markReady, false);
  assert.equal(midway.saveCursor, true);
  const ready = planLookupBackfillResult({
    writeFailed: false,
    done: true,
    canFinish: true,
  });
  assert.equal(ready.markReady, true);
  const same = licenseLookupFields({
    validnum: "特寵業字第W1070485號",
    licenseLookupKey: "W1070485",
    licenseLookupKind: "standard",
    licenseLookupVersion: LOOKUP_KEY_VERSION,
  });
  assert.equal(same.licenseLookupKey, "W1070485");
});

function governmentRow(overrides) {
  return Object.assign({
    govId: "59",
    validnum: "特寵業字第W1070485號",
    normalizedLicense: "特寵業字第W1070485號",
    licenseCore: "W1070485",
    linkStatus: "none",
    licenseStatus: "valid",
  }, overrides || {});
}

function fakeLicenseDb(rows) {
  const calls = [];
  const db = {
    calls: calls,
    collection(name) {
      return {
        where(field, op, value) {
          return {
            limit(limit) {
              return {
                get() {
                  calls.push({
                    collection: name,
                    field: field,
                    op: op,
                    value: value,
                    limit: limit,
                  });
                  const matched = rows.filter((row) => row[field] === value);
                  return Promise.resolve({
                    size: matched.length,
                    docs: matched.map((row) => ({
                      data: () => row,
                    })),
                  });
                },
              };
            },
          };
        },
      };
    },
  };
  return db;
}

test("缺少查核鍵時仍以完整字號比對政府資料", () => {
  const row = governmentRow();
  delete row.licenseLookupKey;
  delete row.licenseLookupVersion;
  assert.deepEqual(
      selectExactLicenseRecords([row], "W1070485").map((item) => item.govId),
      ["59"],
  );
  assert.deepEqual(
      selectExactLicenseRecords([row], "特寵業字第W1070485號"),
      [],
  );
  const folded = governmentRow({
    validnum: "  特寵業字第ｗ１０７０４８５號  ",
  });
  assert.equal(selectExactLicenseRecords([folded], "W1070485").length, 1);
});

test("少一碼、不同字號與不同尾碼不能通過", () => {
  const row = governmentRow();
  assert.equal(selectExactLicenseRecords([row], "W107048").length, 0);
  assert.equal(selectExactLicenseRecords([row], "W1070486").length, 0);
  assert.equal(selectExactLicenseRecords([row], "W10704850").length, 0);
  const suffixed = governmentRow({
    validnum: "特寵業字第V1140460-00號",
    licenseCore: "V1140460",
    licenseLookupKey: "V1140460-00",
  });
  assert.equal(selectExactLicenseRecords([suffixed], "V1140460").length, 0);
  assert.equal(selectExactLicenseRecords([suffixed], "V1140460-01").length, 0);
  assert.equal(selectExactLicenseRecords([suffixed], "V1140460-00").length, 1);
  assert.equal(licenseCoreQueryToken("V1140460-00"), "V1140460");
  assert.equal(licenseCoreQueryToken("W1070485"), "W1070485");
});

test("繁字與已對應其他店家都不會被當成這張一般字號", () => {
  const breeding = governmentRow({
    validnum: "特寵業繁字第W1070485號",
    licenseCore: "W1070485",
  });
  assert.equal(selectExactLicenseRecords([breeding], "W1070485").length, 0);
  const linked = governmentRow({
    linkStatus: "linked",
    certifiedShopId: "other-shop",
    licenseLookupVersion: 0,
  });
  const kept = selectExactLicenseRecords([linked], "W1070485");
  assert.equal(kept.length, 1);
  assert.equal(kept[0].certifiedShopId, "other-shop");
  assert.equal(kept[0].linkStatus, "linked");
  const shown = publicMatch(kept[0], "match", fresh);
  assert.equal(shown.licenseVerified, undefined);
  assert.equal(shown.certifiedShopId, undefined);
  assert.equal(shown.govId, "59");
});

test("查核鍵存在時不再讀取 licenseCore", async () => {
  const row = governmentRow({
    licenseLookupKey: "W1070485",
    licenseLookupVersion: 1,
  });
  const db = fakeLicenseDb([row]);
  const found = await queryByLookupKey(db, "W1070485");
  assert.equal(found.length, 1);
  assert.equal(db.calls.length, 1);
  assert.equal(db.calls[0].collection, "legal_pet_businesses");
  assert.equal(db.calls[0].field, "licenseLookupKey");
  assert.equal(db.calls[0].op, "==");
  assert.equal(db.calls[0].value, "W1070485");
  assert.equal(db.calls[0].limit, LICENSE_LOOKUP_LIMIT);
});

test("查核鍵缺失時只用 licenseCore 等值查詢", async () => {
  const row = governmentRow();
  delete row.licenseLookupKey;
  const db = fakeLicenseDb([row]);
  const found = await queryByLookupKey(db, "W1070485");
  assert.equal(found.length, 1);
  assert.equal(found[0].govId, "59");
  assert.equal(db.calls.length, 2);
  assert.equal(db.calls[1].field, "licenseCore");
  assert.equal(db.calls[1].op, "==");
  assert.equal(db.calls[1].value, "W1070485");
  assert.equal(db.calls[1].limit, 10);
  assert.equal(found[0].linkStatus, "none");
});

test("索引版本不同仍以原始字號為準", async () => {
  const row = governmentRow({
    licenseLookupKey: "W1070486",
    licenseLookupVersion: 99,
    licenseCore: "W1070485",
  });
  const db = fakeLicenseDb([row]);
  const found = await queryByLookupKey(db, "W1070485");
  assert.equal(found.length, 1);
  assert.equal(db.calls[1].field, "licenseCore");
});

test("政府資料不存在時回傳空結果且不掃描", async () => {
  const db = fakeLicenseDb([]);
  const found = await queryByLookupKey(db, "W1070485");
  assert.deepEqual(found, []);
  assert.equal(db.calls.length, 2);
  db.calls.forEach((call) => {
    assert.equal(call.collection, "legal_pet_businesses");
    assert.equal(call.op, "==");
    assert.equal(call.limit, 10);
  });
});

test("備援查詢達到上限且沒有完整相符時視為查詢失敗", async () => {
  const rows = [];
  for (let index = 0; index < 10; index += 1) {
    rows.push(governmentRow({
      govId: "other-" + index,
      validnum: "特寵業字第V1140460-0" + index,
      licenseCore: "V1140460",
      licenseLookupKey: "V1140460-0" + index,
    }));
  }
  const db = fakeLicenseDb(rows);
  await assert.rejects(
      () => queryByLookupKey(db, "V1140460"),
      (error) => error.code === "lookup-truncated",
  );
  assert.equal(db.calls.length, 2);
});

test("權限與查詢錯誤顯示暫時失敗，不是查無資料", async () => {
  const db = {
    collection() {
      return {
        where() {
          return {
            limit() {
              return {
                get() {
                  const error = new Error("permission");
                  error.code = "permission-denied";
                  return Promise.reject(error);
                },
              };
            },
          };
        },
      };
    },
  };
  await assert.rejects(
      () => queryByLookupKey(db, "W1070485"),
      (error) => error.code === "permission-denied",
  );
  const failed = lookupFailureResult({lastSuccessAt: fresh});
  assert.equal(failed.status, "unavailable");
  assert.equal(failed.message, "政府資料查核暫時失敗，請稍後重試。");
  assert.notEqual(failed.status, "none");
  assert.deepEqual(failed.matches, []);
  assert.equal(
      LOOKUP_MESSAGES.none,
      "政府名單目前沒有相符字號，請確認輸入的字號是否正確。",
  );
  assert.equal(LOOKUP_MESSAGES.unavailable, failed.message);
});

test("平台後台字號搜尋仍使用前綴索引", () => {
  const search = planDirectorySearch("W1070485");
  assert.equal(search.kind, "license");
  assert.equal(search.field, "licensePrefixes");
  assert.equal(search.op, "array-contains");
  assert.equal(search.value, "W1070485");
});
