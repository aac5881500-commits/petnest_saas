# 開店引導與住宿預約防呆驗證紀錄

日期：2026-10-19（Asia/Taipei）

## 修改清單

| 專案相對路徑 | 用途 |
| --- | --- |
| `lib/core/services/stay_booking_readiness.dart`（新增） | 共用配置資格、房型／房間雙串流、伺服器重讀、最後房間操作協調與批次啟用篩選。 |
| `lib/core/services/shop_room_service.dart` | 此房型批次啟用；交易內複查房型存在及永久狀態；原本無可用房時，建立／啟用操作同批保持住宿關閉。 |
| `lib/features/shop/widgets/shop_opening_progress.dart`（新增） | 下一步主卡、四個選填入口、使用者與店家各自的 SharedPreferences 收合偏好。 |
| `lib/features/shop/widgets/room_enabled_action.dart`（新增） | 最後房間確認、取消不提交、房間／住宿開關同批寫入、刪除沿用防呆及同店重複操作保護。 |
| `lib/features/shop/pages/shop_dashboard_page.dart` | 移除重播；電話與地址完成判斷沿用既有鎖定工具；在既有新店家範圍向旅店店主顯示引導。 |
| `lib/features/shop/widgets/shop_admin_welcome_dialog.dart` | 移除提醒卡重播入口及 callback，保留首次歡迎與原有兩個選擇。 |
| `lib/features/shop/pages/shop_booking_settings_page.dart` | 開啟與儲存前重讀資格、原因與有權限的修正入口、區分草稿與有效開放狀態、保留失敗草稿、同步同頁房間操作造成的開關變更。 |
| `lib/features/shop/widgets/room_management_section.dart` | 房間停用／刪除防呆、批次啟用送出狀態與結果、沿用共用 enabled 判斷。 |
| `lib/features/shop/widgets/shop_room_type_rooms_hub.dart` | 房型刪除的最後房間防呆及原子提交、共用可售數量判斷。 |
| `lib/features/shop/pages/shop_room_page.dart` | 舊房間管理入口套用相同停用／刪除防呆。 |
| `lib/features/shop/pages/shop_booking_entry_page.dart` | 前台住宿入口同時檢查配置資格；安親保留獨立判斷；區分初次讀取與讀取失敗。 |
| `lib/features/shop/pages/shop_booking_page.dart` | 直接進入住宿頁時套用配置資格；只銜接入口／日期操作開關，未更改結帳、價格或庫存計算。 |
| `lib/features/shop/pages/shop_public_modern_page.dart` | 正式前台住宿入口以有效資格顯示；未改快速模板。 |
| `test/stay_booking_readiness_test.dart`（新增） | 配置、最後房間操作、確認視窗、失敗、日期狀態、安親入口、偏好隔離、方案及卡片布局測試。 |
| `test/shop_admin_welcome_test.dart` | 首次歡迎及移除重播的回歸測試。 |
| `test/shop_room_type_rooms_hub_layout_test.dart` | 擴充手機寬度及展開房間／批次啟用入口的布局驗證。 |
| `docs/shop_opening_readiness_verification.md`（本檔新增） | 修改範圍、實測與未驗證項目。 |

## 引導與資格

- 電話／地址未完成：沿用必要聯絡資料引導與首次設定後鎖定流程。
- 完成後依真實資料依序顯示：建立第一個房型 → 建立實際房間 → 啟用可預約房間 → 前往預約設定。
- 已符合資格且 `bookingEnabled` 不是 false：收起主要開店提醒，留下選填介紹入口。
- 延續 `ShopAdminWelcome.isNewShop` 的日期範圍；主要新卡只向已完成聯絡資料的旅店店主顯示，員工不顯示完整引導。原有管理頁權限與方案檢查保留。
- 基本資料來自既有 shop 即時串流；房型及實際房間各自監聽，從引導進入管理頁返回後另重建串流，不需要 F5。
- 有效房型必須是存在的文件；房間須關聯到該房型，且資料若帶有 shopId，不得屬於其他店家。
- 房間沿用 `DaycareOccupancyService.isRoomDocumentUnsellable`：enabled 不是 false，永久狀態不是 maintenance／blocked／unavailable，包含既有 legacy status 回退規則。
- 現有房型編輯及住宿可售流程未找到額外的房型公開／上架開關，未新增條件。`totalRooms` 不構成實際房間資格。
- 日期滿房、日期關房與清潔不納入此配置資格；原有日期庫存保留。
- 開啟與儲存時使用 Source.server 再讀取；讀取失敗不能當成沒有房間，失敗保留輸入。
- 現有創店預設 bookingEnabled=true。為避免建立／啟用第一間房就自動開放，本次在這些明確操作內，若操作前尚無有效住宿房間，將 bookingEnabled=false 與房間操作同批提交；之後再手動開放。未修改創店流程，也未在開頁時偷偷回寫。
- 選填內容不影響住宿資格；不以點擊入口記錄完成。付費功能沿用既有方案限制並有解鎖說明。

## 舊資料、最後房間與安親

- 舊資料 raw `bookingEnabled` 已開，但配置無效：有效住宿入口關閉，後台顯示「尚未具備住宿預約條件」與修正入口。開頁／build／串流 builder 不回寫住宿設定。
- 停用最後一間且住宿有效開放：先顯示指定確認文案。取消不提交；確認後重讀，再以同一 WriteBatch 寫入房間 enabled=false 及 bookingEnabled=false。提交失敗不顯示成功。
- 原有單房／房型刪除入口同樣加入確認與同批提交，未新增刪除入口、未放寬原有可進入刪除操作的條件；沒有實際刪除正式資料。
- 批次啟用只處理此房型已存在、未啟用且永久狀態允許的房間；交易內再檢查，不覆蓋永久狀態，不寫 bookingEnabled=true。
- 已核對安親使用 `shops.daycareEnabled` 與安親 settings.enabled，住宿使用 bookingEnabled，兩者是獨立開關。最後房間操作不寫安親設定，不更動任何既有訂單。

## 實際檢查結果

以既有 Dart/Flutter SDK 直接執行 CLI snapshot（避開受限制環境中 wrapper 的啟動問題）；權限允許後使用原有 Pub 快取。

- 全專案 `flutter analyze --no-pub`：0 error、9 warning、214 info，exit 1。9 warning 均在本次未修改的檔案。
- 所有本次 Dart 修改與測試檔的精準 `dart analyze`：exit 0，0 error、0 warning；只有 `shop_room_service.dart` 原有 print 的 1 個 info。
- `git diff --check`：通過。
- 以下 7 個檔案一起執行：**34 項全部通過**。
  - `test/stay_booking_readiness_test.dart`
  - `test/shop_admin_welcome_test.dart`
  - `test/shop_contact_setup_guide_test.dart`
  - `test/shop_room_type_rooms_hub_layout_test.dart`
  - `test/shop_room_type_editor_layout_test.dart`
  - `test/shop_permission_v2_test.dart`
  - `test/shop_plan_access_test.dart`
- 已驗證配置階段、孤立／跨店房間、永久不可售、日期清潔不影響配置資格、取消／確認、重讀與寫入失敗傳遞、安親入口選擇、四個入口依方案啟用、偏好依使用者與店家隔離及重建後保留。
- 開店卡、歡迎彈窗、房間管理（含展開與批次入口）：Widget 測試在 320／390／430／1280／1440 寬度沒有 overflow exception。不是正式瀏覽器全頁人工驗收。
- 另外執行 `test/shop_daycare_booking_page_test.dart`：2 項通過、1 項失敗。「第三步顯示優惠券與費用並直接開啟填寫資料」遇到 `[core/no-app]`，未初始化 Firebase；沒有為此修改安親或優惠券程式。該測試不能列為通過。

## 未驗證與後端缺口

- **未驗證**：登入正式 Firebase 後，基本資料儲存返回後台的端到端操作、預約設定儲存失敗的實際遠端回應、首次建房／啟用保持關閉、正式房間批次交易／停用／刪除寫入及遠端拒絕的整合行為。
- **未驗證**：四個管理頁實際登入後的內容編輯、所有員工帳號／方案的端到端畫面、全後台瀏覽器人工布局、正式既有訂單的實際讀取處理。已執行的權限／方案測試與元件測試不能取代這些驗收。
- 本次後端唯讀檢查：`firestore.rules` 的 room_types／rooms 仍允許成員／root 寫入，沒有本次配置資格或最後房間與開關同步的同等限制。
- `functions/bookings` 未找到 bookingEnabled 驗證；`get_stay_availability.js` 還會把房間指向的房型 ID 加入集合，前端此次另外排除了不存在房型的孤立房間。未改 Functions／Rules。
- 因此本次前端防呆**不能防止直接呼叫 API／Firestore，也不能保證跨裝置並行修改時的全域資格不變量**。同一前端的停用／刪除已防止同店重複送出；批次寫入可避免同次操作部分成功，但不是後端全域保護。

## 套用方式與範圍保留

僅需依既有發布流程重新建置並發布 Flutter 用戶端（Web／實際使用的平台）。本次沒有需要部署的 Rules、Storage Rules、Indexes、Functions 或資料遷移；若日後補後端缺口，必須另立任務。

未執行任何部署、commit、branch、正式資料刪除。初始 git status 為乾淨；只留下本次相關檔案修改。創店前流程、條款、圖片、小屋外觀、前台快速模板、訂單、付款、點數、優惠券與房務庫存計算皆未做功能修改。
