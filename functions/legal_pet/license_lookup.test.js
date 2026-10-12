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
  LOOKUP_KEY_VERSION,
} = require("./normalize");

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
  const incomplete = lookupStatusFor({
    license: "W1070485",
    licenseLookupVersion: 0,
    sync: {lastSuccessAt: fresh},
    matchCount: 0,
    nowMs: Date.now(),
  });
  assert.equal(incomplete.status, "incomplete");
  assert.equal(incomplete.shouldQuery, false);
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
