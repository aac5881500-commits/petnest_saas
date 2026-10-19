# 我的店家小屋：圖片全面圖庫化 V1 本機驗證

專案：C:\flutter_apps\petnest_saas  
分支：feature/shop-opening-welcome-v2。未切換或建立分支。

## 完成範圍

沿用 platform_media_library 集合與 platform/media_library/{assetId}/original.{ext} Storage 路徑。沒有建立平行圖庫。
保留 shopHouse 分類與原有七個 placement，新增 house.sceneBackground、house.defaultPhoto，共九個邏輯位置。
屋頂在同一位置分桌機／手機選擇；新增 roofPhoneAssetId，原 roofAssetId 保持相容。素材 device 使用 any / desktop / phone，舊資料視為 any。
首頁完整傳遞 houseAppearance，離開外觀設定頁返回首頁後仍走既有重新載入流程。
展示由 enabled 圖庫串流解析素材，不再只有儲存 ID；未設定時不新增圖庫查詢。
同網址替換素材以既有 updatedAt 產生快取版本鍵，保留原下載 token；只套用小屋分類。
圖片失敗回本機屋頂、窗框、底座、庭院或預設貓咪；牆面保留漸層，上方獨立裝飾隱藏，左右裝飾回既有植物。
Logo 專用、基本 Logo、專用／基本照片、圖庫預設照、本機預設照依序回退；Logo contain，照片 cover，窗框獨立存在。

## 本次檔案（相對專案根目錄）

| 檔案 | 修改 |
|---|---|
| lib/core/models/platform_media_asset.dart | 兩個位置、device／sourceFileName 舊資料相容、URL 與裝置檢查 |
| lib/core/models/shop_house_appearance.dart | 場景／預設照／手機屋頂 ID，序列化、重設與 selectedIds |
| lib/core/models/shop_house_local_assets.dart | 新增七張本機素材的既有圖庫匯入對照與預設縮圖 |
| lib/core/services/platform_media_library_service.dart | 小屋素材裝置／來源資訊、同來源重複上傳檢查、設定頁可略過舊快取讀取 |
| lib/features/platform/pages/platform_media_library_page.dart | 原編輯器選取本機木屋素材、裝置選單、來源顯示；按儲存才進既有上傳流程 |
| lib/features/shop/widgets/platform_media_asset_picker.dart | 九位置、裝置、啟用與有效 URL 篩選，無素材空狀態 |
| lib/features/auth/pages/my_shop_card_media_page.dart | 九位置縮圖、桌機／手機屋頂、恢復預設；保留原儲存流程，新增離線測試注入 |
| lib/features/auth/pages/home_page.dart | 完整外觀設定與基本 Logo／照片失敗回退傳入小屋 |
| lib/features/auth/widgets/shop_entry_panel.dart | 素材解析層與內部展示窗、手機植物連動 |
| lib/features/auth/widgets/shop_house_media.dart | 新增圖庫解析、即時啟用狀態、裝置回退、圖片錯誤回退；已知底座模板保留原九宮格切片 |
| lib/features/auth/widgets/shop_house_scene.dart | 庭院、牆面、屋頂、相框、左右／上方裝飾、底座、預設照連動；保留原本機外觀 |
| test/my_shop_home_carousel_test.dart | 九位置顯示、裝置比例、跨店設定、失敗回退、Logo 順序、設定儲存重載與恢復預設測試 |
| test/shop_house_appearance_test.dart | 九位置、裝置／停用／無效 URL 篩選與空狀態測試 |
| test/previews/shop_house_library_v1/README.md | 本報告與素材對照 |
| test/previews/shop_house_library_v1/default_320.png | 此次 Widget 渲染預覽，保留預設外觀 |
| test/previews/shop_house_library_v1/default_390.png | 同上 |
| test/previews/shop_house_library_v1/default_430.png | 同上 |
| test/previews/shop_house_library_v1/default_1440.png | 同上 |

本次未變更 pubspec.yaml（原目錄已註冊）、shop_service.dart、原始七張圖片，也未改動其他既有未提交工作。

## 圖片對照及待確認上傳

所有檔案位於 assets/images/shop_house/warm_wood/，分類均為「店家小屋」shopHouse。
七張本機檔案有效且皆在 localhost:5000 取得 HTTP 200，SHA256 與原檔一致。
目前預設畫面最多使用六張不同圖片（有 Logo／照片時不顯示貓咪），roof_phone.png 為保留的手機替代款。

| 圖片 | 使用位置 | 顯示組件 | 裝置與本機回退 | 連動 | 上傳狀態 |
|---|---|---|---|---|---|
| roof_wide.png | house.roof / desktop | ShopHouseScene 屋頂 | 桌機；亦為未設定手機專圖時回退，原低屋頂本機預設維持 | 完成 | 正式庫未查證，待查重與確認 |
| roof_phone.png | house.roof / phone | ShopHouseScene 屋頂 | 選定手機版本時優先；失敗依序桌機圖庫圖、本機低屋頂，不拉扁 | 完成 | 正式庫未查證，待查重與確認 |
| window.png | house.windowFrame | ShopHouseDisplayWindow 外框 | 兩版皆用；失敗回本機外框，再回簡潔框線 | 完成 | 正式庫未查證，待查重與確認 |
| plants.png | house.decorationLeft + house.decorationRight | ShopHouseDecoration | 左右獨立設定；原桌機兩側／手機左側位置保留，手機右側僅指定時顯示 | 完成 | 同張可複選左右用途，只需一份，待確認 |
| base.png | house.base | ShopHouseScene 底座 | 已知原尺寸模板沿用九宮格；其他比例完整 contain；失敗回本機底座 | 完成 | 正式庫未查證，待查重與確認 |
| courtyard_daylight.jpg | house.sceneBackground | ShopHouseCourtyard | 兩版 cover；與牆面獨立；失敗回本機庭院 | 完成 | 正式庫未查證，待查重與確認 |
| cat_default.png | house.defaultPhoto | ShopHouseDisplayWindow 內照片 | 沒有可用 Logo／店家照時才用圖庫圖，失敗回本機同圖 | 完成 | 正式庫未查證，待查重與確認 |
| 無獨立圖片 | house.wall | ShopHouseScene 牆面 | 可選未來圖庫素材，預設維持奶油漸層牆 | 完成 | 不虛構／不補空白圖片 |
| 無獨立圖片 | house.decorationTop | ShopHouseScene 上方裝飾 | 原燈飾藤蔓為屋頂合成，保留原圖；未指定時不重複加圖 | 完成 | 未來可上傳獨立素材，目前沒有待轉檔案 |

未操作正式 Firestore 或 Storage，未宣稱七張已轉入正式圖庫。匯入入口只讀取本機圖片與預覽，未按儲存不傳送；實際上傳須另獲確認。
之後若核准上傳，最多七份原圖（約 11.7 MB），沿用既有服務新增素材文件及 Storage 原圖；先以 sourceFileName／原檔名查重，既有同名素材改由編輯維護。這是資料操作，與部署分開。

## 驗證

- 受影響 13 個 Dart 檔案 flutter analyze：No issues found。
- 三份相關測試：49 項通過（my_shop_home_carousel_test、shop_house_appearance_test、platform_media_and_journal_appearance_test）。
- Widget 測試涵蓋 320、390、430、1440，原有測試亦涵蓋其他桌機寬度。九位置 URL 與裝置選擇、真實底座 PNG 解碼／九宮格、缺圖回退、Logo contain、照片 cover、長店名、多店、進入／分享操作皆保留測試。
- 設定選圖、儲存、重建頁面讀回、重設已用離線替身驗證；不是正式 Firestore 寫入驗證。
- 本目錄四張預覽為 Flutter Widget 渲染，已目視確認原木屋與庭院、小檔案保持原外觀，無 overflow 或紅色錯誤圖。
- localhost 七張素材皆 HTTP 200 且雜湊相符；現有 5000 服務原生 hot reload 成功，未停止程序或更換埠。
- 電腦工具無可用瀏覽器／視窗，未執行實際瀏覽器目視驗收、正式圖庫新增／選圖端到端或正式資料持久化測試。
- git diff --check 通過。

## 邊界與風險

1. 不同外觀的自訂窗框仍須配合既有透明開口安全區 (.18, .15, .64, .64)；自訂屋頂招牌需配合模板位置。已知 roof_phone.png 使用其原本招牌區。V1 沒有新增幾何編輯系統。
2. 複合 PNG 原有燈飾與藤蔓不拆圖，另外選裝飾時由平台提供合適素材避免視覺重複。
3. 來源檔名查重可避免一般重複匯入；並非內容雜湊比對／並行上傳交易鎖。正式庫既有未留來源且改名的圖片，匯入前仍須人工確認。
4. 圖庫上傳、正式 Firebase 儲存與實際瀏覽器驗收尚待使用者核准／環境提供。沒有本次新圖片生成，沿用既有有效素材。
5. 本機測試不需部署。未來發布網頁才需要 Hosting；本次不需 Functions、Firestore Rules、Indexes 或 Storage Rules 變更／部署。

未 commit、push、建立分支、部署或執行正式資料操作；保留全部既有本機修改。
