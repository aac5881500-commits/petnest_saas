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


## 持續店家綁定與完整分享卡（2026-10-28）

進店碼僅驗證新進店資格；成功後 shop_customer_bindings/{uid} 記住目前店家。
已進店客人不因改搜尋碼、重設 QR、關閉新入口或舊授權時間到期被踢出。
只有成功驗證另一家進店碼或明確選擇公開店家才切換；失敗查詢不更動綁定。
舊 shop_share_access 授權可作曾進店證明，首次恢復時遷移至目前綁定；沒有證明不能猜 shopId 加入。
重新啟動以後端目前綁定為準；過期舊網址僅能恢復同身分、同店既有綁定，不能讓新訪客進店。
匿名身分若被清除，或改登入另一帳號，屬另一個 UID，仍須重新驗證；不從本機偏好偽造授權。

需新增部署 customerShopBinding、更新 resolveShopSharing 與分享讀取規則，並發布新前端。
本機來源的其他規則可能仍未部署，發布應以線上規則為基礎套用這次差異，避免夾帶其他功能。

分享卡包含真實店名、QR、APP 搜尋碼及網頁版說明。PNG 寬 1080px，列印採固定版型並可由瀏覽器另存 PDF。
搜尋碼未設定時明示未設定，不製造替代碼。本機開發的分享網址使用正式 petnest-saas.web.app；可透過 SHOP_SHARE_ORIGIN 覆寫。
分享是開啟系統分享選單，由店主自行選 LINE；不自動傳給任何聯絡人。印表機實際出紙及 LINE 傳送仍需人工驗收。
