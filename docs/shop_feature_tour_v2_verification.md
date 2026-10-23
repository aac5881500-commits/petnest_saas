# 九頁後台導覽：定位修正與內容擴充

本次以工作區現況局部修改，保留先前與其他任務的未提交內容。已檢查 git status、相關 diff、工作區與祖先路徑；未找到適用的 AGENTS.md。未操作正式店家資料，未建立 branch、commit、push 或部署。未更動資料結構、計價、發點、扣庫存、付款或開店資格規則。

## 定位問題與修正

- 舊 Host 對單一 ID 最後註冊的 anchor 呼叫通用 `Scrollable.ensureVisible`，會沿祖先捲動。條款頁同一 ID 曾同時用於 Tab 與內容；保留中的頁面只憑 mounted／巢狀 route.isCurrent 也可能被選為目標。返回 callback 原先只確認內層沒有 detail，未確認外層模組。
- 本機 widget 測試保留相鄰模組的隱藏目標，實際呼叫舊捲動原語，確認外層 TabController 會從 0 移到 1。這證實跳模組的機制；沒有宣稱已在使用者登入中的真實瀏覽器重現同一張截圖。
- 改為候選 anchor 集合，核對目前導覽／shop／頁面、route、Offstage、IndexedStack 及水平 viewport 的可見性，不讓隱藏目標覆蓋可見目標。
- 只尋找目前 ShopTourPage 內最近的垂直 Scrollable，不捲動外層水平 TabBarView，也不禁用所有正常捲動。
- 條款四點分別定位已發布版本區、退款內容、版本紀錄入口、實際同意紀錄區；移除 Tab 標籤的重複 ID。
- onPoint、定位、返回與恢復核對 session／步驟／頁面；換店、暫停、換步驟、元件失效後不沿用舊回呼。離開確認完成後的導航另核對 stillCurrent。
- 末點通過原有離開檢查、確認外層貓咪旅店及內層實際選單後，才記錄已了解，再亮框下一個真入口。取消離開不記錄完成。
- 定位失敗提供「返回目前介紹頁／重新定位」，保留目前重點；資料錯誤可透過原導航及離開保護重開頁面。只有明確操作才恢復，不使用延遲或輪詢，也不略過不存在的目標。

## 九頁內容與對應面板

| 頁面 | 點數 | 主題 |
| --- | ---: | --- |
| 入住前準備 | 3 | 顧客訂單詳情入口、圖文清單、草稿預覽與條款的差別 |
| 設備管理 | 4 | 房間攝影機對應、HTTPS／原廠 App、顧客說明與內部資訊、測試 |
| 攝影機分享申請 | 4 | 狀態清單、核對／補資料、原廠操作後記錄結果、結束觀看權限 |
| 住宿加購／附加服務 | 5 | 時間單選、整筆每項一次、每隻一次、每日日期時段、耗材庫存 |
| 收款、優惠與點數 | 7 | 訂金基礎、期限、住宿日期加價、自動活動與券、發點、折抵、商品兌換 |
| 商品領取／核銷 | 4 | 實體點數商品、搜尋核對、交付後核銷、取消與過期 |
| 入住規則與貓咪條件 | 4 | 日後改規則、入住／退款條款、歷史版本、同意紀錄 |
| 自訂表單設定 | 4 | 顧客送單、店家建單、整筆／每隻、題型與訂單答案 |
| 每日照護回報設定 | 5 | 提供方式、場次、照護內容、照片限制、顧客外觀與日常入口 |

共同面板映射集中於 shopTourPanels；進度、上下點、末點及 loading anchors 依真實重點數量。偏好沿用原 uid／shopId key，加入本機 contentVersion=2；舊加購庫存映射至新版第 5 點、舊條款紀錄映射至新版第 4 點，不清除其他已了解頁面，也不自動重跑已完成導覽。

介紹卡以段落、淡底範例與提醒呈現，內容可捲動，底部控制不要求先讀到底。頁內導覽只切換顯示，不儲存、發布、核銷、扣點、處理攝影機權限或啟用安親。

## 實際修改檔案

| 完整專案相對路徑 | 用途 |
| --- | --- |
| lib/features/shop/widgets/shop_feature_tour.dart | Controller、候選目標、可見性、有限事件定位、恢復、內容卡及進度遷移 |
| lib/features/shop/widgets/shop_feature_tour_content.dart | 新增九頁 40 點文案、面板與舊版索引對照 |
| lib/features/shop/widgets/shop_dashboard_navigation.dart | 既有 guard 完成後可取消失效導覽導航 |
| lib/features/shop/pages/shop_dashboard_page.dart | 小範圍修正模組確認、真實選單返回、恢復及換店隔離，未重做排版 |
| lib/features/shop/pages/shop_pre_arrival_guide_setting_page.dart | 加入頁面 shop 範圍 |
| lib/features/shop/pages/shop_device_page.dart | 四點、資料讀取與設備空狀態目標 |
| lib/features/shop/pages/shop_camera_access_page.dart | 加入頁面 shop 範圍 |
| lib/features/shop/widgets/camera/shop_camera_access_panel.dart | 四點與錯誤／載入狀態 |
| lib/features/shop/pages/shop_addon_page.dart | 五類目標與映射，補清楚既有計費說明 |
| lib/features/shop/pages/shop_payment_setting_page.dart | 七點對應收款／優惠／點數分頁 |
| lib/features/shop/pages/shop_deposit_setting_page.dart | 兩個收款重點的讀取狀態 |
| lib/features/shop/widgets/shop_deposit_setting_panel.dart | 定位訂金基礎與期限實際卡片 |
| lib/features/shop/pages/shop_discount_setting_page.dart | 定位價格／優惠工具與對應分類，不新增業務寫入 |
| lib/features/shop/pages/shop_point_setting_page.dart | 定位發點、折抵、制度實際卡片與讀取狀態 |
| lib/features/admin/pages/admin_point_redemption_list_page.dart | 四個重點及紀錄讀取狀態 |
| lib/features/shop/pages/shop_policy_page.dart | 四點面板映射、移除重複目標、版本入口 |
| lib/features/shop/pages/shop_policy_logs_page.dart | 同意紀錄內容的載入／錯誤目標 |
| lib/features/shop/pages/shop_custom_form_settings_page.dart | 四點對應現有表單卡片與店家範圍 |
| lib/features/shop/pages/daily_care_setting_page.dart | 五點對應真實規則／內容／照片／外觀區 |
| test/shop_feature_tour_test.dart | 更新並擴充為八個局部本機案例 |
| docs/shop_feature_tour_v2_verification.md | 本次變更與驗證紀錄 |

## 說明的唯讀核對

- booking_detail_page、booking_detail_preparation_section：入住前準備來自訂單詳情入口；付款期限倒數及住宿到期取消檢查在詳情頁，不承諾所有訂單即時取消或自動退款。
- booking_addon_section：每日日期含入住日、不含退房日；多寵物同時段受服務設定限制。
- booking_service、finalize_booking_addon_inventory（唯讀）：建立後嘗試扣加購耗材、入住前再確認，每次綁定量乘實際購買次數，同筆防重扣。
- discount_campaign_calculator：符合條件的活動按折抵額擇優，同額先建立者優先；券併用另受開關限制。
- points/booking_points（唯讀）、point_setting_model：服務結束且無待補／待退才符合發點條件；按晚數或淨收金額及上限計算，N 點折 NT$1；不是下單即發點。
- custom_form_model、daily_care_setting_page：題型、訂單答案歸屬、照護模式及目前照片／保存提示。

## 執行驗證與限制

- 修改檔案 Dart format 已執行。
- 八個 shop_feature_tour_test 案例通過：舊進度與索引校正；390／1440 巢狀模組、隱藏重複目標及條款→選單→表單→照護；恢復同點及暫停後 guard 不導航；失效啟動；收款七點真三分頁；照護五點真三分頁且寫入 callback 為零；九頁 40 點真入口與唯讀遮罩／離開取消／本機接續；權限、方案及讀取失敗不完成。
- 只對修改檔案執行 analyze，無 error。保留既有 daily_care_setting_page 四個 unused_element warning，以及 dashboard 原有一處大括號 info；未整理無關舊方法。
- git diff --check 已執行，無空白錯誤。
- 未進入正式店家或寫入營運資料。九頁完整登入瀏覽器、真實 Firestore 載入、各頁實際空資料／權限組合、實機鍵盤與旋轉、使用者原截圖的完整登入情境均未驗證。widget fixture 測試不等於這些實機流程已通過。
- 正式 Web 套用需重新建置並部署 Hosting；本次無後端修改，不需部署 Functions、Rules、Indexes，也未執行任何部署。
