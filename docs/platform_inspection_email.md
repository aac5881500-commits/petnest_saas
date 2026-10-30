# 唯讀查核 Email 驗證碼

查核頁不再使用 reauthenticateWithPopup、重新輸入密碼或近期 auth_time 解鎖。

1. 已登入固定 APP 最高權限帳號，按「寄送驗證碼」。
2. inspectShop 的 send_code 從 Firebase Admin Auth 讀取該 UID 的已驗證 Email；忽略客戶端指定收件者。
3. 輸入六位數後呼叫 verify_code，成功後建立 email_code_v1 查核工作階段。
4. 同次驗證可跨店；閒置 30 分鐘、手動鎖定或登入改變後失效。

驗證碼 5 分鐘內有效、單次使用、錯誤最多五次。重寄間隔 60 秒、一小時最多五次，重寄使舊碼失效。寄送失敗不宣告成功，錯誤嘗試會提交 transaction，不因拋錯回滾。

只保存 scrypt 雜湊與獨立 salt，不回傳或記錄明文驗證碼。挑戰與帳號/已驗證信箱/登入 auth_time 綁定。送信與驗證只寫 platform_inspection_email_codes、platform_inspection_email_limits、platform_inspection_sessions、platform_inspection_logs，不修改店務資料。

## 部署

需更新既有 inspectShop function 與 Flutter 前端；沒有新增第二個登入步驟或另開登入視窗。
沿用專案店家清理郵件的 SMTP 帳號設定，但不共用其驗證碼或授權：
SHOP_DELETION_SMTP_HOST / FROM / USER / PASS 四項 Secret，及既有 PORT、SECURE 環境設定。

未設定 SMTP 會明確失敗，不在前端假裝已寄送。新 function 需綁定以上四項既有 Secret。舊 begin action 與舊密碼解鎖 session 不再被接受；需前後端一起更新。

本次未部署、未讀取實際 Secret 值、未寄出測試郵件；實際 SMTP 收信與正式環境需人工驗收。
Firestore rules/indexes/Storage rules 未新增修改；Email/session/log 集合沿用預設拒絕客戶端存取。
