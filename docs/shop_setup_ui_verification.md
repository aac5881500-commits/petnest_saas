# 開店引導與房型工作區 UI 驗證

日期：2026-10-20（Asia/Taipei）。本次接續本機所有未提交修改，沒有還原前次住宿預約防呆。

## 本輪實際修改的完整專案相對路徑

| 路徑 | 用途 |
| --- | --- |
| `lib/features/shop/widgets/shop_opening_progress.dart` | 三階段真實狀態卡；桌機任務／進度雙欄、手機單欄；四個選填圖示小卡與原有本機收合偏好、方案限制。 |
| `lib/features/shop/pages/shop_dashboard_page.dart` | 同一張三階段卡涵蓋新旅店店主的基本資料階段；避免同時顯示重複提醒；既有新店家範圍與員工限制保留。 |
| `lib/features/shop/widgets/shop_room_type_rooms_hub.dart` | 單一置中空白狀態、明確新增／編輯入口；固定房間／房型訂閱；響應式切換不卸載編輯器；整合與獨立頁離開防護。 |
| `lib/features/shop/widgets/shop_room_type_editor.dart` | 基本資料雙欄短欄位、上限說明、照片詳細資訊收合、尺寸選填、特色去重圖示、適中介紹欄、底部固定操作列；保留草稿與照片；儲存／載入期間防重複及 await 後生命週期檢查。 |
| `lib/features/shop/widgets/shop_room_type_live_preview.dart` | 預覽外框最高 740，既有前台介紹在內部捲動，維持閱讀寬度與 previewOnly，未改正式前台風格。 |
| `lib/features/shop/widgets/shop_room_type_workspace.dart`（新增） | 房型管理與獨立編輯器共用的局部雙區工作區；固定 Stack／Positioned 父子關係，以有界 Offstage 顯示面板，避免斷點重建草稿。 |
| `lib/features/shop/widgets/shop_setup_leave_guard.dart`（新增） | 可綁定且防重複的非同步離開確認，供本次房型／預約整合流程使用。 |
| `lib/features/shop/pages/shop_booking_setup_center_page.dart` | 修正入口切同頁分頁；房型與預約草稿的分頁／離開確認；防止重複確認與 pop；可注入測試讀取來源。 |
| `lib/features/shop/pages/shop_booking_settings_page.dart` | 嵌入時 callback 切回同頁；獨立頁仍可導航；資格／操作紀錄訂閱由 State 管理，dispose 時取消；放棄變更真正還原草稿，防重複離開／導航。 |
| `test/shop_setup_lifecycle_test.dart`（新增） | 完整整合頁操作、重複修正入口、返回、斷點、照片與草稿、儲存失敗／防重複、成功回呼、鍵盤及載入中離開測試。 |
| `test/shop_setup_visual_test.dart`（新增） | 使用專案本機字體及安全 fixture 輸出手機／桌機 PNG，不操作正式資料。 |
| `test/shop_room_type_editor_layout_test.dart` | 更新按鈕文案與可見雙欄／單欄行為驗證，不依賴拆卸子樹的版型 Key。 |
| `test/stay_booking_readiness_test.dart` | 保留前次狀態與停用防呆測試，增加基本資料同頁切階段，調整選填卡片驗證，加入 768 寬度。 |
| `docs/shop_setup_ui_verification.md`（本檔新增） | 本輪範圍、錯誤證據、結果與未驗證項目。 |

## 已確認問題與錯誤證據

1. 同一個已掛載 hub 在 390 寬新增房型、輸入「跨斷點草稿」、切到 1280：修正前文字變成空白。該回歸測試先實際失敗，修正後通過。根因是 Row 與 Column／IndexedStack 的不同子樹位置卸載並重建內嵌編輯器。
2. 整合頁反覆切換房型／預約、由修正入口切回、編輯與放棄草稿，再跨越單／雙欄斷點：捕捉到第一個 Flutter exception：`Bad state: Stream has already been listened to.`
3. 當時 stack 首段如下（節錄，不是使用者瀏覽器原始完整 stack）：

```text
_StreamBuilderBaseState._subscribe (widgets/async.dart:133:38)
_StreamBuilderBaseState.initState (widgets/async.dart:107:5)
StatefulElement._firstBuild (widgets/framework.dart:5953:55)
ComponentElement.mount (widgets/framework.dart:5796:5)
Element.inflateWidget (widgets/framework.dart:4590:20)
MultiChildRenderObjectElement.inflateWidget (widgets/framework.dart:7269:36)
MultiChildRenderObjectElement.mount (widgets/framework.dart:7285:32)
```

4. 已確認的串流問題：預約設定卡在響應式 Row／單欄 ListView 之間重新掛載，子卡內的 StreamBuilder 再次監聽同一條單訂閱 readiness 串流。操作紀錄亦有相同重新掛載風險。本次將這兩項訂閱放到 State 的 initState／dispose，保留最後 snapshot，避免版型切換再次訂閱。shop、房型與房間讀取來源也在各相關頁面局部固定，沒有重構全站服務。
5. 同批失敗操作測試的後續曾出現與截圖相同的 framework.dart:6271 `_dependents.isEmpty` assertion；隔離照片測試則通過。本次先修正已捕捉的第一個串流錯誤，沒有吞例外、改 ErrorWidget、關 assertion、加 UniqueKey 或延遲掩蓋。
6. 相同完整操作與單訂閱 fixture 在修正後通過，沒有再次訂閱錯誤、6271 assertion 或 overflow。測試診斷器在失敗時輸出第一個 exception 與原始 stack，仍呼叫 Flutter 測試原有錯誤處理。
7. **未獨立重現**：使用者原始瀏覽器的 framework.dart:6420 ancestor／descendant assertion；沒有原始瀏覽器完整 stack，不能宣稱所有截圖的唯一根因已確認或所有瀏覽器紅畫面已完全修復。

## 介面與操作結果

- 基本資料、房型與房間、開放住宿預約，顯示已完成／進行中／待完成；基本資料依原有完成判斷，房間依前次共用資格，預約依真實開關；不以點擊入口當完成。
- 零房型只顯示一個「新增第一個房型」主要操作；空白狀態沒有刪除警告。有資料時警告降低視覺比重，原刪除確認與防呆保留。
- 表單保留全部原欄位、數值限制、特色 key、資料格式及正式裁切／上傳路徑；未新增套件、假介紹或圖片素材。
- 新增「建立房型」、編輯「儲存變更」；按鈕固定於編輯區底部，內容獨立捲動，鍵盤上方可操作。
- 縮放與管理／預覽切換保留同一個編輯器 State、文字及待上傳照片。
- 分頁／返回時，有變更則確認；繼續編輯不丟資料，明確放棄才退出。預約的「放棄變更」會還原已儲存草稿，避免反覆要求確認。導航與送出都有防重複狀態。
- 照片處理失敗不再繼續退出編輯器；保留未完成照片及已取得房型 ID，成功上傳部分不重複加入待上傳清單。真實遠端部分失敗仍列在下方未驗證。
- 前次無有效房型／實際可用房間的資格、手動開放、最後房間確認／原子提交、批次啟用、日期庫存、安親獨立開關等程式保留。

## 已執行驗證

- 受影響的 9 個來源 Dart 檔與 4 個測試 Dart 檔執行 `dart analyze`：**No issues found**。
- 9 個相關測試檔一起執行：**41 項全部通過**。
  - `test/stay_booking_readiness_test.dart`
  - `test/shop_setup_lifecycle_test.dart`
  - `test/shop_setup_visual_test.dart`
  - `test/shop_room_type_editor_layout_test.dart`
  - `test/shop_room_type_rooms_hub_layout_test.dart`
  - `test/shop_admin_welcome_test.dart`
  - `test/shop_contact_setup_guide_test.dart`
  - `test/shop_permission_v2_test.dart`
  - `test/shop_plan_access_test.dart`
- 驗證同一已掛載頁面的 320／390／430／768／1280／1440 寬度切換，含整合頁、引導卡、房型編輯與照片草稿；沒有測得紅畫面或 overflow。
- 測試包含：修正入口不增加整合頁 route、反覆分頁、房型取消／返回確認、預約繼續／放棄、編輯儲存回呼成功與失敗、送出中按鈕停用且不重複呼叫、鍵盤 280 避讓、權限與照片載入中 dispose。
- 真實遠端寫入以安全測試回呼替代；測試成功不代表已驗證正式 Firestore／Storage 儲存。
- 正式本機字體的 Widget 視覺輸出已生成並人工檢視：
  - `build/shop_setup_visuals/opening_390.png`
  - `build/shop_setup_visuals/opening_1440.png`
  - `build/shop_setup_visuals/editor_390.png`
  - `build/shop_setup_visuals/editor_1440.png`
- `git diff --check`：通過。此處分析與測試使用專案既有 Flutter／Pub 快取，沒有新增套件。

## 未驗證與正式套用

- **未驗證**：登入後本機瀏覽器端到端操作、原始截圖環境、真實照片選擇器／裁切器／Storage 上傳、正式新增與編輯房型、真實遠端權限拒絕與部分寫入失敗、預約「儲存並離開」的正式遠端提交。
- 非測試環境的實際瀏覽器平台／輸入法／軟鍵盤與全後台版面，仍需實機驗收；Widget 的尺寸與鍵盤模擬不能代替所有裝置。
- 本次沒有執行全專案測試；已執行的相關回歸不代表全部專案測試通過。前次報告中的後端保護缺口仍存在，本次沒有擴大成後端修正。
- 正式套用只需依既有流程重新建置並發布 Flutter 用戶端；本次沒有 Rules／Indexes／Functions／Storage Rules 部署或資料遷移需求。
- 未部署 Hosting、未 commit、未建立 branch、未新增套件、未操作或刪除正式資料。所有初始未提交變更保留。
