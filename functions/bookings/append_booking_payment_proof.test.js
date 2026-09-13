// 檔案名稱：functions/bookings/append_booking_payment_proof.test.js
// 功能說明：付款回傳照片 purpose 正規化與多筆紀錄

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeProofPurpose,
  buildPaymentProofRecord,
  applyLast5ToProofs,
  last5LegacyMeta,
  imageAppendBookingFields,
  LEGACY_IMAGE_FIELDS,
} = require("./append_booking_payment_proof");

test("top_up 新資料寫成 balance，deposit 維持訂金", () => {
  assert.equal(normalizeProofPurpose("deposit"), "deposit");
  assert.equal(normalizeProofPurpose("balance"), "balance");
  assert.equal(normalizeProofPurpose("top_up"), "balance");
  assert.equal(normalizeProofPurpose("additional"), "balance");
});

test("不支援的 purpose 拋錯", () => {
  assert.throws(() => normalizeProofPurpose("other"), /付款類型不正確/);
});

test("多筆 proof 各自保留 proofId 與 purpose", () => {
  const a = buildPaymentProofRecord({
    proofId: "p1",
    imageUrl: "https://a/1.jpg",
    storagePath: "booking_images/b1/1.jpg",
    purpose: "deposit",
    amount: 500,
    last5: "11111",
    submittedBy: "u1",
    submittedAt: "t1",
  });
  const b = buildPaymentProofRecord({
    proofId: "p2",
    imageUrl: "https://a/2.jpg",
    storagePath: "booking_images/b1/2.jpg",
    purpose: "balance",
    amount: 1300,
    last5: "22222",
    submittedBy: "u1",
    submittedAt: "t2",
  });
  assert.notEqual(a.proofId, b.proofId);
  assert.equal(a.purpose, "deposit");
  assert.equal(b.purpose, "balance");
  assert.equal(a.storagePath, "booking_images/b1/1.jpg");
});

test("新流程寫入欄位不含 legacy 圖片 URL／path", () => {
  const depositKeys = imageAppendBookingFields("deposit", true);
  const balanceKeys = imageAppendBookingFields("balance", true);
  const last5Deposit = Object.keys(last5LegacyMeta("deposit", "12345", "now"));
  const last5Balance = Object.keys(last5LegacyMeta("balance", "67890", "now"));
  for (const key of LEGACY_IMAGE_FIELDS) {
    assert.equal(depositKeys.includes(key), false);
    assert.equal(balanceKeys.includes(key), false);
    assert.equal(last5Deposit.includes(key), false);
    assert.equal(last5Balance.includes(key), false);
  }
});

test("補送訂金後五碼只改訂金 record，不改結算尾款", () => {
  const proofs = [
    {proofId: "d1", purpose: "deposit", imageUrl: "https://a/d.jpg", last5: "11111"},
    {proofId: "b1", purpose: "balance", imageUrl: "https://a/b.jpg", last5: "22222"},
  ];
  const result = applyLast5ToProofs(proofs, "deposit", "99999");
  assert.equal(result.updated, true);
  assert.equal(result.proofs[0].last5, "99999");
  assert.equal(result.proofs[1].last5, "22222");
  assert.equal(result.proofs[1].imageUrl, "https://a/b.jpg");
});

test("補送尾款後五碼只改尾款 record，不改訂金", () => {
  const proofs = [
    {proofId: "d1", purpose: "deposit", imageUrl: "https://a/d.jpg", last5: "11111"},
    {proofId: "b1", purpose: "balance", imageUrl: "https://a/b.jpg", last5: "22222"},
  ];
  const result = applyLast5ToProofs(proofs, "balance", "88888");
  assert.equal(result.updated, true);
  assert.equal(result.proofs[0].last5, "11111");
  assert.equal(result.proofs[1].last5, "88888");
});

test("沒有同用途圖片時不可改到另一用途圖片", () => {
  const proofs = [
    {proofId: "b1", purpose: "balance", imageUrl: "https://a/b.jpg", last5: "22222"},
  ];
  const result = applyLast5ToProofs(proofs, "deposit", "33333");
  assert.equal(result.updated, false);
  assert.equal(result.proofs[0].last5, "22222");
  assert.equal(result.proofs[0].imageUrl, "https://a/b.jpg");
});

test("已確認的同用途照片不可被後五碼改寫", () => {
  const proofs = [
    {
      proofId: "d1",
      purpose: "deposit",
      imageUrl: "https://a/d.jpg",
      last5: "11111",
      confirmedAt: "t1",
    },
  ];
  const result = applyLast5ToProofs(proofs, "deposit", "44444");
  assert.equal(result.updated, false);
  assert.equal(result.proofs[0].last5, "11111");
});

test("相同後五碼允許寫入", () => {
  const proofs = [
    {proofId: "d1", purpose: "deposit", imageUrl: "https://a/d.jpg", last5: "55555"},
  ];
  const result = applyLast5ToProofs(proofs, "deposit", "55555");
  assert.equal(result.updated, true);
  assert.equal(result.proofs[0].last5, "55555");
});
