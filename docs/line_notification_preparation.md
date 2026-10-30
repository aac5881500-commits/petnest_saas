# LINE 通知選配：階段一準備與後續接續

本機已實作準備資料的介面/讀寫/防誤啟用；未開通 LINE、未部署、未申請方案、未連接外部帳號，也不會發送 LINE。

## 階段一的入口與範圍

會員消息中心右上角「LINE 通知前置設定」。店主可儲存公開帳號資料與預計用途；有會員消息權限的員工僅檢視。
- Messaging API 的公開官方帳號 ID、Channel ID 不等於驗證成功。
- 不收、不存、不回傳 Access Token / Channel Secret；未知欄位直接拒絕。
- phase 永遠 preparation_only，ready/sendingEnabled/billingActivated 永遠 false。不可透過寫入 prepared/ready 等旗標開通。
- 沒有向 LINE 的 HTTP request，沒有 webhook endpoint，沒有付費或綁定 API。
- 既有 App / FCM 獨立運作。campaign 帶 channel=line、sendLine=true 或 channels 包含 line 時，拒絕而非假裝送達。

## 資料與 API 契約

既有 `manageShopCampaign` callable，沿用 auth/shop/會員消息權限檢查：
- `linePreparation`：讀取 `{shopId}`，回傳 canEdit、version、configuration 與不可發送狀態。
- `saveLinePreparation`：店主限定；參數 `{shopId, version, configuration}`；transaction 檢查 version，舊版資料回 aborted。
- `configuration` 只允許 displayName(<=80)、officialAccountId(@公開ID)、channelId(5~20數字)、requestedUses(booking/personal/promotion)。可留空，表示尚未準備。
- 私有文件 `shop_line_preparations/{shopId}`，Admin SDK 寫入。前端只透過 callable，不開放直接讀寫規則。
- 支援狀態只是「已填寫資料」；不回傳、也不信任未知機密欄位。
- 新版 callable 尚未部署時，頁面清楚顯示服務暫不可用，可看準備清單，不能宣稱已儲存。

## 正式串接前還必須完成（本階段未做）

1. 商業開通：店主自行管理 LINE 官方帳號與訊息方案，平台另訂選配服務。平台 entitlement/付款確認由伺服器核發，不接受店主傳 ready=true。不得擅自代訂方案或自動加購。
2. 憑證管理：每店區分 Secret Manager 資源與 IAM；不進 shops 公開文件、Flutter bundle、一般設定或 log。驗證 bot/profile 與 Channel 所屬官方帳號後才能記錄 verified，支援換鑰/撤銷。
3. Webhook：新增專用 HTTPS endpoint，根據伺服器可信路由決定店家/憑證，不相信 body 的 shopId。先驗證原始 rawBody 的 x-line-signature HMAC-SHA256，再 parse JSON，做 event id 防重放/去重。本階段僅提供 verifyLineSignature 純工具，尚未暴露 endpoint。
4. 客戶綁定：每店獨立官方帳號需加好友並完成一次綁定。使用官方 account-link 流程、單次 token 與不可預測 nonce，綁定 appUid/shopId/provider/channel/LINE userId，防混店、冒名及重放；禁止以手機/顯示名稱猜 LINE userId。取消好友、解除綁定與接收意願需同步撤銷發送資格。
5. 發送政策：同時通過店家 entitlement、已驗證憑證/webhook、客戶綁定/同意/好友狀態、用途偏好、平台停用限制、店家額度與 LINE 月額度；任一未知就不發送。不能僅憑本頁準備資料派送。
6. 發送工作者：App/FCM/LINE 分別記錄處理結果、錯誤與 retry key；重試不得重複扣額度/群發。LINE 失敗不應破壞已成功的 App 通知。控制發送上限、不自動加購。
7. 隱私與體驗：先做訂單/個別服務的選配，再開優惠。權益限制訊息只顯示中性 LINE 摘要/安全連結，詳細原因限登入 App 查看。避免一則廣告無條件 App/FCM/LINE 三重打擾；讓會員管理各店偏好。
8. 以測試帳號做 quota、封鎖、token撤銷、重播、跨店與錯送驗收，確認後才逐店啟用。

## 部署界線

階段一僅需人工更新 `manageShopCampaign` 以使用準備資料 API，以及建置/發布前端。未新增 LINE webhook/發送 trigger；沒有新增 rules/indexes/storage 變更。先前 campaign 發送與每店手機靜音的待部署清單仍獨立存在，不代表已部署。

## 官方參考（2026-10-30 查閱）

- 官方帳號/Channel 建立：https://developers.line.biz/en/docs/messaging-api/getting-started/
- Webhook 原始內容簽章：https://developers.line.biz/en/docs/messaging-api/verify-webhook-signature/
- 安全帳號綁定：https://developers.line.biz/en/docs/messaging-api/linking-accounts/
- 訊息額度/費用：https://developers.line.biz/en/docs/messaging-api/pricing/

本文件不固定寫入未來價格；正式開通時重新確認台灣方案。
