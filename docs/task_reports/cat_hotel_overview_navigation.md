# 貓咪旅店總覽與快速導航修改紀錄

功能說明：調整店家後台貓咪旅店的桌機總覽與外層導航，沿用原頁面、權限及資料服務。

## 修改範圍

- `lib/features/shop/pages/shop_dashboard_page.dart`：貓咪旅店共用入口定義、寬版總覽、專用導航狀態與側欄模式。安親條件改由單一穩定訂閱供卡片及側欄共用，不複製統計監聽。
- `lib/features/shop/widgets/shop_dashboard_navigation.dart`：每個模組保有不同的 Navigator key，使用同一套切換邏輯；次級頁維持父功能選取，同一路由內多個設定面板可共同登記離開檢查。
- 以下頁面僅增加必要的離開介面或草稿／忙碌檢查，沒有改動儲存資料、計算或設定版面：
  - `lib/features/shop/pages/shop_booking_setup_center_page.dart`
  - `lib/features/shop/pages/shop_pre_arrival_guide_setting_page.dart`
  - `lib/features/shop/pages/shop_policy_page.dart`
  - `lib/features/shop/pages/daily_care_setting_page.dart`
  - `lib/features/shop/pages/shop_custom_form_editor_page.dart`
  - `lib/features/shop/pages/shop_daycare_settings_page.dart`
  - `lib/features/room/pages/room_dashboard_page.dart`
  - `lib/features/shop/pages/shop_deposit_setting_page.dart`
  - `lib/features/shop/pages/shop_point_setting_page.dart`

## 排版與導航

- 使用內容區 LayoutBuilder 的實際寬度。至少 1180 且沒有聊天／前台分割占用時，啟用寬版；最大寬度 1680，左右內距 28，區塊間距 18。
- 今日營運置頂，最多三欄。下方左右約 65／35：住宿與房型設定最多兩欄；收費及規則分類各為滿寬直式入口。
- 每個 Grid 會依實際入口寬度減少欄數，卡片與文字自然增高。窄視窗及分割模式沿用原有總覽配置。
- 總覽仍只建立原有權限允許的四個主分類，沒有展開子功能。
- 貓咪旅店內頁只顯示貓咪旅店快速選單及「返回貓咪旅店總覽」。基本資訊仍使用自己的導航狀態與入口。
- 同層切換會先檢查離開保護，再替換內容路由；不累積同層頁面。不重複開啟目前選取功能。
- 保留既有穩定的店家 Stream，以及內容 Navigator 的 State、掛載位置與生命週期。

## 入口逐項核對

以下完整頁面均已接入同一條貓咪旅店快速選單。所有頁面保留原有 `shopId`，權限、必要資料及方案判斷由同一份卡片定義提供。

| 分組 | 入口 | 沿用目標與行為 |
| --- | --- | --- |
| 今日營運 | 訂單管理 | `AdminBookingListPage`；保留原待確認、付款回傳及新留言統計 |
| 今日營運 | 房務管理／營運工作台 | `RoomDashboardPage`；保留 `/shop-operations-workbench` 路由名稱、原工作台分頁與內部功能 |
| 今日營運 | 店家聊天 | 動作型入口，保留 `ShopChatEntry.open(toggleDesktop: false)`、原浮層／側欄及未讀徽章；不選中假內頁 |
| 住宿與房型設定 | 住宿房型與預約 | `ShopBookingSetupCenterPage`；沿用房型、房間及預約分頁，側欄切換會呼叫原房型／預約離開檢查 |
| 住宿與房型設定 | 安親設定 | `ShopDaycareSettingsPage`；僅在現有安親啟用與權限條件成立時顯示 |
| 住宿與房型設定 | 入住／安親前準備 | `ShopPreArrivalGuideSettingPage`；保留原分類名稱、圖片清理及離開確認 |
| 住宿與房型設定 | 設備管理 | `ShopDevicePage`；內部操作方式不變 |
| 住宿與房型設定 | 攝影機分享申請 | `ShopCameraAccessPage`；保留原擁有者／設備權限判斷，以及卡片原待邀請、待取消統計 |
| 收費、優惠與加購 | 住宿加購 / 附加服務 | `ShopAddonPage`；沿用原管理頁與編輯方式 |
| 收費、優惠與加購 | 收款、優惠與點數 | `ShopPaymentSettingPage`；沿用原三個分頁，訂金與點數草稿接入離開檢查，不改資料處理 |
| 收費、優惠與加購 | 商品領取／核銷 | `AdminPointRedemptionListPage`；保留原搜尋、領取與核銷頁面 |
| 規則與紀錄 | 入住規則與貓咪條件 | `ShopPolicyPage`；保留 `canEdit = managePolicy && canUsePolicySettings`，無編輯權限仍依原邏輯查看紀錄 |
| 規則與紀錄 | 自訂表單設定 | `ShopCustomFormSettingsPage`；其編輯次級頁仍保留返回關係及原離開確認 |
| 規則與紀錄 | 每日照護回報設定 | `DailyCareSettingPage`；沿用原離開選項與使用者明確選擇的儲存流程 |

共 12 個常態完整頁面入口，啟用安親時增加 1 個；聊天是獨立動作型入口。沒有強制補出被權限隱藏的入口。

## 驗證與限制

- 已格式化本次修改的 11 個 Dart 檔案。
- 已執行這 11 檔的局部靜態分析：無 error；保留 5 項既有未使用方法 warning、3 項既有風格／棄用 info，未整理無關程式碼。
- 已執行上述檔案 `git diff --check`，沒有差異空白錯誤。
- 已逐項核對入口、路由名稱、必要參數、權限及特殊開啟方式。
- 未做實際瀏覽器驗證：寬窄視窗、設定與營運頁停留、側欄切換、聊天、取消未儲存離開、基本資訊回歸及導引定位均未宣稱通過。
- 未改動的次級頁若有自己的返回攔截，共用導航仍保守交由該攔截處理，不強制跳過保護；完成返回後可再選目的頁。
- 沒有跑全專案測試、完整 build、golden 或大量自動化，也沒有建立訂單、入住、收款、核銷或變更正式設定。
- 本次僅需後續更新 Flutter Web／Hosting。未提交 Git、未建立分支、未部署，沒有變更 Firebase 結構、Functions 或規則。
