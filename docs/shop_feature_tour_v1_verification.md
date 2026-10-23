# 後台功能導覽 V1

本次只新增本機閱讀導覽，不寫入營運設定或 Firestore 導覽欄位。未部署、未建立分支、未 commit，未操作正式店家資料。其他視窗正在修改的前台及版型檔案未由本次工作修改或整理。

## 實際修改清單

| 完整專案相對路徑 | 用途 |
| --- | --- |
| `lib/features/shop/widgets/shop_feature_tour.dart` | 九頁內容、穩定 ID、錨點、共用唯讀遮罩、焦點限制、閱讀進度及本機保存、暫停／接續／重看／完成卡 |
| `lib/features/shop/pages/shop_dashboard_page.dart` | 依真實選單與權限建立名單、貓咪旅店入口、沿用內容導航、開始前確認開店狀態、帳號與店家隔離 |
| `lib/features/shop/pages/shop_booking_settings_page.dart` | 僅在第一階段導引正式儲存開放成功後，於既有完成提示提供「繼續認識後台」 |
| `lib/features/shop/pages/shop_pre_arrival_guide_setting_page.dart` | 住宿開關、圖文新增區及預覽入口錨點；導覽固定在住宿；讀取失敗不算完成 |
| `lib/features/shop/pages/shop_device_page.dart` | 房間設備固定區與相容性說明錨點；空設備與讀取中／失敗處理 |
| `lib/features/shop/pages/shop_camera_access_page.dart` | 真實分享申請頁識別 |
| `lib/features/shop/widgets/camera/shop_camera_access_panel.dart` | 狀態篩選、原廠權限說明與固定統計區錨點，不依賴申請紀錄 |
| `lib/features/shop/pages/shop_addon_page.dart` | 時間、其他服務及庫存入口錨點，切換既有區域、讀取狀態及草稿離開保護 |
| `lib/features/shop/pages/shop_payment_setting_page.dart` | 既有三分頁切換及本機測試內容替換介面，正式入口仍使用真實子頁 |
| `lib/features/shop/pages/shop_deposit_setting_page.dart` | 收款設定區錨點與讀取失敗狀態 |
| `lib/features/shop/pages/shop_discount_setting_page.dart` | 已載入優惠工作區錨點 |
| `lib/features/shop/pages/shop_point_setting_page.dart` | 已載入點數設定標頭錨點及錯誤狀態 |
| `lib/features/admin/pages/admin_point_redemption_list_page.dart` | 領取搜尋與狀態分頁錨點，不建立／交付／取消兌換紀錄 |
| `lib/features/shop/pages/shop_policy_page.dart` | 住宿／退款分頁、已發布版本區與同意紀錄錨點，不改草稿、模板及發布驗證 |
| `lib/features/shop/pages/shop_custom_form_settings_page.dart` | 真實兩種表單卡片錨點，等待各自串流，不建立題目或模板 |
| `lib/features/shop/pages/daily_care_setting_page.dart` | 真實三分頁錨點；導覽只切換顯示面板，保留所有草稿及整頁離開保護 |
| `test/shop_feature_tour_test.dart` | 五個直接相關的本機驗證案例 |
| `docs/shop_feature_tour_v1_verification.md` | 本次修改與驗證紀錄 |

## 九頁介紹與定位

1. 入住前準備：行前提醒用途 → 新增標題／文字／圖片 → 客戶畫面預覽。導覽不切安親、不上傳或儲存。
2. 設備管理：房間觀看方式 → HTTPS／外部 App → 相容性與測試說明。沒有設備時仍可讀固定區塊，不測試連線。
3. 攝影機分享申請：狀態篩選 → 原廠 App 手動完成權限 → 無申請屬正常情況。不建立或處理申請。
4. 住宿加購／附加服務：時間加購 → 加值／客製／每日分時段的用途 → 庫存設定入口。不接受預設價格為已確認價格。
5. 收款、優惠與點數：實際依序選中三個既有分頁，分別介紹訂金、活動優惠、會員點數，不啟用或儲存。
6. 商品領取／核銷：搜尋欄與固定工具區 → 四種狀態 → 實際交付後才核銷。空資料仍可介紹，不執行核銷或退點。
7. 入住規則與貓咪條件：住宿及版本區 → 退款分頁 → 同意紀錄分頁。不重新套模板或發布條款。
8. 自訂表單設定：顧客送單卡片 → 店家手動建單卡片 → 訂單／寵物資訊用途。未介紹停用的新增寵物表單。
9. 每日照護回報設定：實際依序選中回報規則 → 照護內容 → 外觀設定，不修改場次、欄位、收費或外觀。

訂單管理、房務管理、店家聊天、住宿房型與預約均不參與第二階段；不加入安親教學。

## 進入、閱讀與保存

- 第一階段成功開放且完成日期說明後，使用既有成功提示中的「繼續認識後台」交接。原頁結束後回同店後台，選中貓咪旅店，不堆疊新的後台首頁。
- 既有店家可由貓咪旅店的小型入口主動開始；不因 `bookingEnabled` 為 true 自動播放。開始時唯讀確認基本資料、實際房間、已發布住宿條款及正式住宿開放狀態。
- 每頁必須點進真實入口。頁內使用共用介紹卡與真實元件錨點；營運控制區不穿透點擊，鍵盤導覽限制在允許的入口與介紹操作內。
- 最後一步先沿用 `ShopDashboardNavigation.switchTo` 的離開檢查。取消離開或離開未完成時，不記錄已了解。
- 無權限的項目不參與；原入口受方案或必要資料限制時只介紹限制並略過，與已了解分開保存。進度總數只計算可進頁介紹的項目。
- SharedPreferences key：`shopFeatureTour:v1:<uid>:<shopId>`。保存穩定頁面 ID、目前重點、已了解清單、略過原因、暫停及完成狀態。僅本機，不宣稱跨裝置同步。
- 重新開頁先維持暫停；接續時仍要進入對應真實頁。完成後入口改為「重新查看功能導覽」，只重設閱讀進度。
- 遮罩是工作區內 Widget，隨頁面及 host dispose 清理，不建立全域常駐 OverlayEntry。

## 實際驗證

- 針對以上修改的 Dart 檔案執行格式與 analyze。無 error；保留每日照護原有四個 unused_element 警告與後台原有一個括號格式 info，未為此刪除舊方法或整理無關區域。
- `test/shop_feature_tour_test.dart`：五個案例通過。
  - 非同步啟動或離開確認期間暫停，舊回呼不重新啟動導覽、不記錄已了解或完成。
  - 收款真實三分頁容器，使用本機內容替身，驗證依序切換。
  - 真實每日照護頁，注入設定，驗證三分頁切換且 saveOverride 呼叫為零。
  - 九頁入口／閱讀狀態測試，390／1440 寬度；驗證入口不能直接算完成、遮罩阻擋營運按鈕、離開取消不記完成、27 個重點、完成卡、重看與暫停接續、不同店家隔離。
  - 無權限／方案限制與讀取失敗不記為已了解。
- `test/shop_setup_lifecycle_test.dart` 僅執行既有兩個案例：`最小驗證：預約缺省、載入、有效狀態與舊店保留`、`住宿開放導引：真開關、日期說明與草稿保護`，皆通過。
- 差異空白檢查僅針對本次檔案。

未驗證：登入真實瀏覽器後的完整九頁導航與所有方案／員工組合、正式資料讀取權限錯誤、成功開放後的真實跨頁交接、實體裝置觸控／旋轉／鍵盤、各頁大量內容時的實際捲動視覺。未操作正式資料，不把上述本機替身測試當作真實後端整合通過。

## 發布

本機先查看。正式 Web 採用後重新建置並更新 Hosting；本次不需部署 Functions、Rules、Indexes 或其他後端設定。

## 2026-10-23 接續收尾

先核對工作樹與既有修改，未重做九頁導覽，也未更動另一個任務的前台／版型內容。本輪只修改共用導覽控制器、其測試與本紀錄：加入導覽 session 檢查，讓暫停、權限名單移除目前頁面及 dispose 使舊的非同步結果失效；已失效的回呼不再改寫目前頁面、已了解或完成狀態。

本輪實際執行：上述兩個 Dart 檔案格式及 analyze（無問題），單一功能導覽測試檔五個案例通過。未重新執行全專案檢查或先前住宿測試，未進行真實瀏覽器、正式資料或部署操作；先前列出的未驗證項目維持未驗證。
