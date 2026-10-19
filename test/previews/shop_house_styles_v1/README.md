# 兩套新小屋風格 V1：本機素材與圖庫上傳準備

專案 C:\flutter_apps\petnest_saas；分支 feature/shop-opening-welcome-v2。
狀態：兩套各十張素材完成，正式上傳尚未核准，未上傳、未寫入正式 Firestore、未套用任何店家。

## 真正圖片生成

使用內建 image_gen 圖片生成能力，每個部件獨立生成，不使用原木屋改色、不以幾何圖形代替插畫。精確提示詞、來源及修正版記錄見 generation.json。
浪漫花園：灰藍魚鱗瓦、白色雕花屋簷／相框、粉白花草、白色花盆及柵欄、淺色木牆與平台。
現代日式：炭灰低斜屋瓦、胡桃木樑及格柵相框、簡約竹葉、石燈與紙感燈具、米白灰泥、深木平台。
屋頂、窗框、裝飾及底座均為真透明 PNG；牆面、庭院與預設貓照為 JPEG（品質85）。輸出只做等比例縮放、格式壓縮、底座外圍透明空白裁整，不塗改圖案、不建立空白占位圖。
所有圖片無固定店名、編號、狀態、統計或按鈕。組合預覽中的文字、Logo、狀態與數字由既有 Flutter 元件繪製，為離線測試資料。

## 實際位置與規格

現有九個邏輯位置不變。屋頂分桌機與手機版本，因此每套十張；沒有新增分類、用途識別值、集合、樣式設定或全站主題系統。

| 位置 | 本次尺寸／比例 | 現有顯示與安全區 |
|---|---|---|
| house.roof 桌機 | 2172×724，3:1 PNG | 依原圖比例計算高度，contain；動態店名在(.375,.49,.25,.18)，招牌不進入下方資訊區 |
| house.roof 手機 | 1086×362，3:1 PNG | 專用較簡化細節，contain；缺少手機圖可回桌機，未指定仍為舊木屋 |
| house.wall | 1024×1024，1:1 JPG | cover，寬／窄內容會不同裁切；材質中央保持低對比無物件 |
| house.windowFrame | 1024×1024，1:1 PNG | contain；原照片開口(.18,.15,.64,.64)，Logo 含原內距的安全區全透明，無格柵遮住 Logo |
| house.decorationLeft | 512×768，2:3 PNG | contain；桌機130px寬、手機展示窗旁38px寬 |
| house.decorationRight | 512×768，2:3 PNG | contain；桌機95px寬、手機35px寬；左右為不同圖案 |
| house.decorationTop | 768×512，3:2 PNG | contain；左上角槽寬=屋寬.12、高=屋頂高.25，不置於招牌中央 |
| house.base | 2172×285，約7.62:1 PNG | 原桌機54px、手機28px高；本次兩張同規格模板沿用原九宮格(180,30)-(1992,255)、scale4 |
| house.sceneBackground | 1536×1024，3:2 JPG | cover 庭院環境層；關鍵細節放邊緣，中央不放房子或固定資訊 |
| house.defaultPhoto | 1024×1024，1:1 JPG | 只有缺少可用 Logo／店家照時才顯示，cover；與外框分離 |

完整逐圖尺寸、格式、大小與 SHA256 見 asset-audit.json；所有二十張皆可解碼、非空、低於現有5MiB單張限制。相框 Logo 安全區不透明像素比例=0。

## 既有圖庫流程與待核准操作

沿用 PlatformMediaLibraryService.uploadAsset()；集合 platform_media_library；Storage 路徑 platform/media_library/{assetId}/original.png 或 original.jpg。
既有上傳器支援 JPG／PNG／WebP 與5MiB限制，原圖位元組直接上傳、支援 alpha。編輯器會解碼讀取尺寸，但不強制拒絕比例，也沒有自動圖片壓縮；本次已在本機先輸出合適尺寸和 JPEG 壓縮。
同一個 shopHouse 分類，依既有 placements、device、sourceFileName 及中文名稱前綴分組，沒有新增 style Firestore 欄位。
新增目錄只提供平台編輯器讀取本機素材。選取只預覽，不按儲存不上傳，沒有自動批次上傳程式。

正式上傳清單見 UPLOAD_LIST.md，完整20份文件欄位見 upload-plan.json。總量 12454900 bytes（約 11.88 MiB）。
計畫每張新增一個素材文件、原圖 Storage 物件；imageUrl／thumbnailUrl 於上傳後由既有 getDownloadURL 取得，時間與管理員欄位由原服務填入，enabled=true，排序200–209與300–309。
清單中的 {autoId_XX} 是審核用占位符，沒有保留ID、沒有建立文件。實際 ID 由既有 uploadAsset() 核准後產生。再次上傳前須查重，現有 sourceFileName／原檔名查重繼續沿用，不刪除或覆蓋既有圖庫。
不修改 shops/{shopId}.houseAppearance 或店家 Logo／照片，因此新增圖庫不會自動換掉店家外觀。

## 實際修改／新增路徑

| 檔案 | 內容 |
|---|---|
| lib/core/models/shop_house_local_assets.dart | 新增兩套各十張可選匯入來源、中文名稱與排序；原七張 warmWoodEntries 與預設路徑維持 |
| lib/features/platform/pages/platform_media_library_page.dart | 現有本機匯入選單顯示中文素材名並填入既有排序欄位，原權限與上傳流程不變 |
| lib/features/auth/widgets/shop_house_media.dart | 僅允許本次兩個底座檔名在原2172×285模板下沿用九宮格，原木屋顯示不變 |
| pubspec.yaml | 僅新增兩個素材目錄宣告 |
| test/shop_house_new_styles_test.dart | 新增目錄完整性、真實解碼、透明安全區、招牌不遮資訊、四種寬度及Logo／預設照片共17項測試 |

新增正式素材：

- assets/images/shop_house/romantic_garden/romantic_garden_roof_wide.png
- assets/images/shop_house/romantic_garden/romantic_garden_roof_phone.png
- assets/images/shop_house/romantic_garden/romantic_garden_wall.jpg
- assets/images/shop_house/romantic_garden/romantic_garden_window.png
- assets/images/shop_house/romantic_garden/romantic_garden_decoration_left.png
- assets/images/shop_house/romantic_garden/romantic_garden_decoration_right.png
- assets/images/shop_house/romantic_garden/romantic_garden_decoration_top.png
- assets/images/shop_house/romantic_garden/romantic_garden_base.png
- assets/images/shop_house/romantic_garden/romantic_garden_courtyard.jpg
- assets/images/shop_house/romantic_garden/romantic_garden_cat_default.jpg
- assets/images/shop_house/modern_japanese/modern_japanese_roof_wide.png
- assets/images/shop_house/modern_japanese/modern_japanese_roof_phone.png
- assets/images/shop_house/modern_japanese/modern_japanese_wall.jpg
- assets/images/shop_house/modern_japanese/modern_japanese_window.png
- assets/images/shop_house/modern_japanese/modern_japanese_decoration_left.png
- assets/images/shop_house/modern_japanese/modern_japanese_decoration_right.png
- assets/images/shop_house/modern_japanese/modern_japanese_decoration_top.png
- assets/images/shop_house/modern_japanese/modern_japanese_base.png
- assets/images/shop_house/modern_japanese/modern_japanese_courtyard.jpg
- assets/images/shop_house/modern_japanese/modern_japanese_cat_default.jpg

新增本機報告、來源記錄與預覽：

- test/previews/shop_house_styles_v1/generation.json
- test/previews/shop_house_styles_v1/asset-audit.json
- test/previews/shop_house_styles_v1/upload-plan.json
- test/previews/shop_house_styles_v1/UPLOAD_LIST.md
- test/previews/shop_house_styles_v1/baseline-sha256.json
- test/previews/shop_house_styles_v1/preservation-audit.json
- test/previews/shop_house_styles_v1/export_assets.ps1
- test/previews/shop_house_styles_v1/contact_sheets.ps1
- test/previews/shop_house_styles_v1/romantic_garden_contact.png
- test/previews/shop_house_styles_v1/modern_japanese_contact.png
- test/previews/shop_house_styles_v1/romantic_garden_320.png
- test/previews/shop_house_styles_v1/romantic_garden_390.png
- test/previews/shop_house_styles_v1/romantic_garden_430.png
- test/previews/shop_house_styles_v1/romantic_garden_1440.png
- test/previews/shop_house_styles_v1/modern_japanese_320.png
- test/previews/shop_house_styles_v1/modern_japanese_390.png
- test/previews/shop_house_styles_v1/modern_japanese_430.png
- test/previews/shop_house_styles_v1/modern_japanese_1440.png
- test/previews/shop_house_styles_v1/README.md

## 驗證結果

- dart format 僅本次四個 Dart 檔案。
- flutter analyze 四個相關 Dart 檔案：No issues found。
- 最終四份相關測試共66項通過（新17項、原49項）。
- 兩套各在320／390／430／1440px測試Logo及預設貓照，真實圖片解碼，無RenderFlex overflow。八張組合預覽為Widget實際渲染，另有兩張素材總覽，皆已目視檢查。
- 目視發現日式招牌遮住桌機名稱後已重新生成縮短招牌，最終預覽已無該遮擋，並加入下緣透明安全區測試。
- 原木質暖心風七張素材 SHA256 皆與任務開始一致，shop_house_scene.dart 原排版完全未修改，證據見 preservation-audit.json。
- git diff --check 通過；原有未提交修改保留，未整理或還原其他工作。
- 本次未重新啟動、停止、改埠或重載現有 localhost 程序；新風格只在離線測試套用，沒有變更目前正式使用外觀。
- 尚未驗證正式平台圖庫查詢、正式Storage下載或瀏覽器登入後套用：因尚未核准上傳，本次不聲稱已驗證。

## 交付與限制

本機素材與新增準備完成，沒有缺少部件。正式上傳須使用者先核准 UPLOAD_LIST.md 與 upload-plan.json；目前沒有上傳核准，也沒有正式 Firebase 操作。
目前使用者需逐部位選圖，沿用既有設定方式，沒有新增一鍵整套換裝或變更任何店家已選素材。
新目錄註冊後，既有 Flutter Web 服務未必僅靠hot reload就更新資源清單；之後測試平台本機匯入選單時可能需正常重新啟動開發服務，本次未動該程序。
素材本身不需Hosting、Functions、Firestore Rules、Storage Rules或Indexes部署。若未來要發布本機程式變更至正式網頁，才另行規劃Hosting；不得把素材上傳和Hosting部署混為一談。
未commit、push、建立或切換分支、部署、修改Rules／Indexes／Functions、寫入商店設定或刪除資料。
