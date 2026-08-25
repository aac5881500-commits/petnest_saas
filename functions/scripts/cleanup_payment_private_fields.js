// functions/scripts/cleanup_payment_private_fields.js
// 🧹 Payment 隱私欄位清理工具
// 功能：掃描 payments，移除舊資料中的 callbackData / customerPhone。
// ⚠️ 只刪除這兩個欄位，不會刪除整筆 Payment。

const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

async function main() {
  console.log("開始掃描並清理 payments...");

  const snapshot = await db.collection("payments").get();

  let callbackDataCount = 0;
  let customerPhoneCount = 0;
  let affectedPaymentCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();

    const hasCallbackData =
      Object.prototype.hasOwnProperty.call(data, "callbackData");

    const hasCustomerPhone =
      Object.prototype.hasOwnProperty.call(data, "customerPhone");

    if (!hasCallbackData && !hasCustomerPhone) {
      continue;
    }

    affectedPaymentCount += 1;

    const updates = {};

    if (hasCallbackData) {
      callbackDataCount += 1;
      updates.callbackData = admin.firestore.FieldValue.delete();
    }

    if (hasCustomerPhone) {
      customerPhoneCount += 1;
      updates.customerPhone = admin.firestore.FieldValue.delete();
    }

    console.log(
      [
        `準備清理 Payment: ${doc.id}`,
        `callbackData: ${hasCallbackData ? "刪除" : "無"}`,
        `customerPhone: ${hasCustomerPhone ? "刪除" : "無"}`,
      ].join(" | "),
    );

    await doc.ref.update(updates);
  }

  console.log("");
  console.log("===== 清理結果 =====");
  console.log(`Payment 總數：${snapshot.size}`);
  console.log(`已處理 Payment：${affectedPaymentCount}`);
  console.log(`已刪 callbackData：${callbackDataCount}`);
  console.log(`已刪 customerPhone：${customerPhoneCount}`);
  console.log("====================");
  console.log("");
  console.log("Payment 隱私欄位清理完成。");
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("清理 Payment 失敗：", error);
    process.exit(1);
  });
