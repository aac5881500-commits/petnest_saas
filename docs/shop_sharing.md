# 店家專屬分享

營業資訊與首頁分享頁共用設定，獨立於公開找店開關。首次不產生搜尋碼或 QR。
搜尋碼可留空；非空為 8–32 位英數字、底線、連字號，禁止 SHOP 流水號。
QR 使用 192 位元隨機 token。搜尋碼與 token 的索引使用 SHA-256，設定與索引均禁止客戶端直接讀寫。
修改權限：ownerUid、owner 成員、edit_business_info 或根管理員。
每帳號每 10 分鐘 15 次查詢，每來源 IP 每 10 分鐘 60 次；成功失敗皆計數。
訪客先匿名登入，後端驗證後發出 24 小時讀取授權；重設、修改搜尋碼或關閉分享會撤銷先前授權。
重啟分享產生新 QR，避免之前已停用的 QR 復活。既有訂單仍沿用原本授權規則。

## 上線

需一併部署 manageShopSharing、resolveShopSharing、Firestore rules 與新版前端；未部署前不要宣稱正式站已生效。
未公開店家舊 SHOP 碼將停用，店家需於營業資訊建立分享入口並更新提供給客人的 QR。
Firebase Authentication 需啟用匿名登入，讓未登入客人掃碼；已登入帳號沿用原身分。
Web 分享連結使用目前 origin；原生預設 https://petnest.tw，可用 SHOP_SHARE_ORIGIN dart-define 指定正式網址。
分享碼為持有即可進入的入口，客人轉傳仍可被其他人使用；不等同身分白名單。

## 測試

僅針對 demo-private-sharing 專案，啟動 Firestore 模擬器於 127.0.0.1:8188，再於 test/firestore_rules 執行 npm run test:sharing。
模擬器使用 -Duser.language=en -Duser.country=US，避免 zh_TW 資源缺漏。
flutter test test/shop_sharing_code_test.dart 驗證掃碼與手動輸入解析。
