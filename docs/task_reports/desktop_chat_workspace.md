# 桌機聊天占位與多對話切換修改紀錄

功能說明：店家後台桌機聊天改用占位工作區，沿用既有訊息服務與文字草稿。

## 修改檔案

- `lib/features/shop/pages/shop_dashboard_page.dart`：聊天從覆蓋浮層改為 Row 的實際占位；依剩餘 constraints 配置管理區及全域預覽。集中聊天時以 Offstage 保留原管理頁、Navigator 與表單，不清除路由。移除聊天浮層排序引起的 Dashboard setState，前台工具列改為局部監聽聊天寬度變化。
- `lib/features/shop/widgets/chat/shop_chat_desktop_workspace.dart`：清單／單一對話、最近對話分頁、「更多」、集中模式與返回清單。任一時間僅建立一個完整對話，展開／收回沿用相同對話 State。
- `lib/features/shop/widgets/chat/shop_chat_layout.dart`：桌機門檻 1100，標準側欄寬度 380。
- `lib/features/shop/controllers/shop_chat_multi_dock_controller.dart`：後台集中使用同一聊天工作區，停用同時顯示舊浮窗；沿用 threadId 草稿及既有本機儲存。保留最近最多六個快速入口，超出可見數量放在更多清單。切換時保留進行中傳送狀態，成功傳送只清除該對話相符的已送出文字，不清除其他對話或較新的草稿。
- `lib/features/shop/widgets/chat/shop_chat_inbox_list.dart`：清單搜尋／篩選仍使用既有工作區狀態，捲動由同一 controller 與 PageStorageKey 保存；店家及收件匣 Stream 在相同身分下重用，重試仍會重新建立來源。
- `lib/features/shop/widgets/chat/shop_chat_thread_pane.dart`：僅作用中對話掛載訊息 Stream；相同對話重建時重用來源。沿用工作區文字 controller，非工作區才建立自己的 controller；已卸載對話不執行排程中的已讀操作。桌機窄標頭將既有次要操作放入更多選單，保留會員姓名、返回、會員資料及附件入口。依既有店家啟用狀態停用輸入，未放寬服務端權限。
- `lib/features/shop/widgets/shop_room_type_workspace.dart`：聊天造成實際寬度不足時收合房型手機預覽，保留管理區與導引目標，提供「查看預覽」彈窗。

## 寬度與模式

- 桌機聊天為實際占位的 380 logical pixels；不再使用 Positioned 疊在後台操作上。
- 工作區扣除導航後不足 940 寬時，以集中聊天顯示，提供返回後台／關閉聊天。使用者也能明確點擊展開／收回。
- 集中模式寬度至少 720 時，清單與對話左右顯示；其他情況共用同一側欄切換。收到訊息不改變目前選取或主動展開。
- 只扣除實際存在的導航、聊天、前台預覽各一次。聊天關閉後恢復空間。
- 房型預覽與管理區的原雙欄門檻為實際寬度 1100。聊天開啟且不足此門檻時，優先顯示管理區；預覽改由 Dialog 顯示。沒有修改原預覽選取旗標或全域前台預覽偏好，空間恢復後依原條件恢復。
- 手機使用原完整聊天流程；未改造手機聊天版面。

## 草稿與監聽

- 使用既有店家／使用者／threadId 草稿隔離及 SharedPreferences 機制，沒有新增 Firestore 草稿集合。
- 切換分頁、返回清單、展開、收回及關閉聊天不清除文字。快取僅保留有限的文字 controller，沒有快取所有完整對話頁。
- 依可用寬度顯示最多四個快速分頁，其餘放在更多；只顯示摘要未讀，不因 hover 或分頁存在而標記已讀。
- 附件仍使用原選取、驗證及傳送流程，沒有新增大型檔案的永久暫存或自動上傳。

## 驗證

- 已格式化本次七個修改 Dart 檔案，並執行局部靜態分析：無 error／warning，僅 dashboard 原有括號風格 info。
- 已執行上述檔案 `git diff --check`，沒有差異空白錯誤。
- 已核對占位寬度、獨立管理區、作用中單一對話、草稿識別、清單返回及預覽條件的程式路徑。
- 未實際驗證瀏覽器畫面、真實對話分頁與草稿、附件、集中模式表單保留、導引定位、窄視窗及預覽恢復；沒有可宣稱通過的互動測試。
- 沒有發送真實訊息、上傳附件、建立會員／對話或變更正式設定；沒有執行全專案測試、完整 build 或大量自動化。
- 後續僅需更新 Flutter Web／Hosting。本次未提交 Git、未建立分支、未部署，沒有修改 Firebase 結構或規則。
