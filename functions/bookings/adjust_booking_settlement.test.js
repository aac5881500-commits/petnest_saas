// 檔案名稱：functions/bookings/adjust_booking_settlement.test.js
// 功能說明：結算尾款核對改讀 paymentProofs[]

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  selectBalanceProofForReview,
  missingBalanceProofMessage,
  patchProofs,
  normalizeProofPurpose,
} = require("./adjust_booking_settlement");

test("top_up additional 正規化為 balance", () => {
  assert.equal(normalizeProofPurpose("top_up"), "balance");
  assert.equal(normalizeProofPurpose("additional"), "balance");
  assert.equal(normalizeProofPurpose("balance"), "balance");
  assert.equal(normalizeProofPurpose("deposit"), "deposit");
});

test("paymentProofs 有 balance、legacy 圖為空仍可選到待核對", () => {
  const proofs = [
    {proofId: "d1", purpose: "deposit", imageUrl: "https://a/d.jpg"},
    {
      proofId: "b1",
      purpose: "balance",
      imageUrl: "https://a/b.jpg",
      submittedAt: "2026-09-13T04:00:00.000Z",
    },
  ];
  const selected = selectBalanceProofForReview(proofs, "");
  assert.equal(selected.error, undefined);
  assert.equal(selected.proof.proofId, "b1");
  assert.equal(selected.alreadyConfirmed, undefined);
});

test("有 proofId 時只核對該筆，不可誤選訂金", () => {
  const proofs = [
    {proofId: "d1", purpose: "deposit", imageUrl: "https://a/d.jpg"},
    {proofId: "b1", purpose: "balance", imageUrl: "https://a/b.jpg"},
  ];
  const deposit = selectBalanceProofForReview(proofs, "d1");
  assert.equal(deposit.error, "沒有待核對的結算尾款轉帳證明");
  const balance = selectBalanceProofForReview(proofs, "b1");
  assert.equal(balance.proof.proofId, "b1");
});

test("只有訂金照片時回傳尚未提交結算尾款轉帳證明", () => {
  const proofs = [
    {proofId: "d1", purpose: "deposit", imageUrl: "https://a/d.jpg"},
  ];
  assert.equal(
      missingBalanceProofMessage(proofs),
      "尚未提交結算尾款轉帳證明",
  );
  const selected = selectBalanceProofForReview(proofs, "");
  assert.equal(selected.error, "尚未提交結算尾款轉帳證明");
});

test("已確認的 balance 不可再被選成待核對", () => {
  const proofs = [
    {
      proofId: "b1",
      purpose: "balance",
      imageUrl: "https://a/b.jpg",
      confirmedAt: "t1",
    },
  ];
  const selected = selectBalanceProofForReview(proofs, "b1");
  assert.equal(selected.alreadyConfirmed, true);
  const next = patchProofs(proofs, 0, {confirmedAt: "t2", confirmedBy: "staff"});
  assert.equal(next[0].confirmedAt, "t2");
  assert.equal(proofs[0].confirmedAt, "t1");
});

test("取 submittedAt 最新的未確認 balance", () => {
  const proofs = [
    {
      proofId: "old",
      purpose: "balance",
      imageUrl: "https://a/old.jpg",
      submittedAt: "2026-09-01T00:00:00.000Z",
    },
    {
      proofId: "new",
      purpose: "balance",
      imageUrl: "https://a/new.jpg",
      submittedAt: "2026-09-13T00:00:00.000Z",
    },
  ];
  const selected = selectBalanceProofForReview(proofs, "");
  assert.equal(selected.proof.proofId, "new");
});

test("住宿佔用日不含退房日", () => {
  const {stayDateKeys} = require("./adjust_booking_settlement");
  const keys = stayDateKeys({
    startDate: "2026-09-13T00:00:00+08:00",
    endDate: "2026-09-16T00:00:00+08:00",
  });
  assert.deepEqual(keys, ["2026-09-13", "2026-09-14", "2026-09-15"]);
});
