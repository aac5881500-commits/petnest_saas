# 基本資訊桌機快速導航修改紀錄

功能說明：基本資訊內頁共用既有左側導航，沿用現有表單與服務。

## 範圍與行為

- 後台外框實際寬度至少 1200 時，使用 240 寬的同一條左側導航，基本資訊可展開分類與快速入口。
- 卡片與子選單共用 `_BasicInfoTab.menuChildren` 的入口、權限、方案及開店鎖定條件。
- 基本資訊使用局部 Navigator，選取完整頁面才建立該頁；同層切換經離開檢查後回到內容區根路由，再開啟新頁，不累積同層返回層數。
- 重複點選目前內頁不重複載入。內頁自行開啟的次級路由、Dialog 及返回結果沿用原實作。
- 手機／窄視窗新開入口仍使用原有完整頁面方式。已開啟的桌機編輯頁縮窄時保留目前 Navigator 與輸入，不另外掛載一份。
- 基本資訊總覽保留方案、引導及雙欄成果；雙欄仍依實際內容寬度至少 1180 啟用。

## 逐項入口對照

以下 16 個完整頁面均整合至桌機右側內容區；`shopId` 與原有角色參數保留。

| 分類 | 入口 | 原有目標檔案 |
| --- | --- | --- |
| 店家資料 | 店家基本資料 | `lib/features/shop/pages/shop_basic_info_page.dart` |
| 店家資料 | 營業資訊 | `lib/features/shop/pages/shop_business_info_page.dart` |
| 店家資料 | 店家封面 | `lib/features/shop/pages/shop_media_page.dart` |
| 店家資料 | 收款帳戶 / 金流設定 | `lib/features/shop/pages/shop_payout_setting_page.dart` |
| 店家資料 | 金流中心 | `lib/features/admin/pages/admin_payment_center_page.dart`（只沿用，未修改） |
| 前台內容 | 前台外觀設定 | `lib/features/shop/pages/shop_theme_setting_page.dart` |
| 前台內容 | 環境介紹管理 | `lib/features/shop/pages/shop_environment_manage_page.dart` |
| 前台內容 | 關於我們管理 | `lib/features/shop/pages/shop_about_manage_page.dart` |
| 前台內容 | 公告管理 | `lib/features/shop/pages/shop_announcement_manage_page.dart`（只沿用，未修改） |
| 前台內容 | 常見問題管理 | `lib/features/shop/pages/shop_faq_manage_page.dart`（只沿用，未修改） |
| 會員系統 | 會員管理 | `lib/features/admin/pages/admin_member_list_page.dart`（只沿用，未修改） |
| 會員系統 | 評價管理 | `lib/features/admin/pages/admin_review_list_page.dart`（只沿用，未修改） |
| 後台管理 | 平台通知 | `lib/features/shop/pages/shop_platform_notification_page.dart`（只沿用，未修改） |
| 後台管理 | 聯絡平台 | `lib/features/shop/pages/shop_contact_platform_page.dart` |
| 後台管理 | 模組設定 | `lib/features/shop/pages/shop_module_settings_page.dart`，保留 `currentUserRole` |
| 後台管理 | 權限設定 | `lib/features/shop/pages/shop_permission_settings_page.dart`，保留 `currentUserRole` |

前台預覽是第 17 個入口，維持 `_handleFrontendPreview` 的既有內嵌手機預覽／展開／完整預覽判斷，屬動作型入口，不永久切換側欄選取。未新增外部連結或假頁面。

聯絡平台實際是案件清單頁，建立案件與案件詳細頁仍沿用原路由。模組設定實際是完整儲存頁。公告／常見問題仍在管理頁內開啟原編輯 Dialog，沒有改成另一套表單。

## 離開保護與返回

- 外觀、環境、關於我們、權限頁的既有判斷與提示銜接到側欄切換，環境補足文字欄位的草稿比較。
- 基本資料、營業資訊、銀行／綠界草稿、模組設定、封面草稿及聯絡平台建立案件補上必要離開保護。
- 無修改時不顯示放棄提醒；已成功儲存的區段更新草稿基準。自動儲存的開關仍沿用原流程。
- 儲存、圖片處理及相關送出中的狀態阻止切離。未新增自動儲存或資料請求。
- 取消離開不切換頁面或側欄選取。正常儲存返回與次級頁的 `await Navigator.push` 結果沿用；導引仍等待頁面返回並更新原有準備狀態。
- 若未接入共用介面的次級頁使用自己的返回攔截，導航會交給該攔截並停止本次切換；不強制越過保護。完成其返回後可再選目的頁。

## 實際修改檔案

- `lib/features/shop/pages/shop_dashboard_page.dart`：同一條側欄、共用入口定義、內容區導航、實際寬度及引導進出判斷。
- `lib/features/shop/widgets/shop_dashboard_navigation.dart`：新增內容 Navigator、路由觀察、同層切換及離開介面。
- 上表中基本資料、營業資訊、封面、收款設定、外觀、環境、關於我們、聯絡平台、模組及權限共 10 個店家頁：必要離開保護及非同步載入後的存活檢查。
- `lib/features/shop/pages/store/shop_store_banner_editor_page.dart`：僅補上 controller 的忙碌狀態唯讀 getter，供封面頁離開檢查使用。
- `lib/features/shop/widgets/shop_opening_progress.dart`：為原路由提供定位名稱，桌機沿用內容 Navigator、窄視窗沿用完整頁面；返回後的原刷新邏輯保留。
- 本文件：入口及驗證紀錄。

## 驗證與限制

- 已格式化上述 14 個 Dart 修改檔案。
- 已對上述 14 檔執行局部靜態分析：無 error／warning，7 項既有 info（括號風格、finally 內 return、null-aware 與 Radio 棄用提示）。
- 已執行修改檔案的 `git diff --check`，無差異空白錯誤。
- 已逐項核對 17 個入口、參數、可見性、鎖定及特殊開啟方式。
- 未進行瀏覽器畫面實測、未儲存 Dialog 互動、視窗縮放、導引狀態及聊天／預覽遮擋實測。
- 未跑全專案／整合／golden 測試，未 build，未操作正式資料。
- 僅需後續更新 Flutter Web／Hosting；本次未提交 Git、未建立分支、未部署，未變更 Firebase 結構或規則。
