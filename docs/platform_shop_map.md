# 平台地圖找店

## 功能
- 探索首頁的地圖入口使用原公開店家即時串流，沿用搜尋、服務分類、營業篩選。
- 桌面左店家列表、右地圖；手機上地圖、下列表，點標記後顯示可捲動店卡。
- 拖曳地圖後按「搜尋這個範圍」，僅在已讀公開店家中篩選，不呼叫 Places Nearby Search。
- 未公開店家一律排除；取消公開時同步移除卡片與標記。
- 只有 `mapLocation.confirmed == true`、有限有效經緯度且 `addressSnapshot` 等於現店址才標示。地址變更需店主重新確認；未設定者仍在列表，絕不以城市中心冒充店址。
- 點標記/卡片定位不重新建立地圖。沒有自動地址轉座標，也沒有每位訪客的 Geocoding 請求。

## 店主設定
「營業資訊 → 地圖找店位置」：輸入緯度與經度、勾選確認、按儲存。
由 `saveShopMapLocation` callable 核對 ownerUid 或 shop_members 店主角色，檢查當前地址快照後，只更新 mapLocation/updatedAt。非店主拒絕；保存位置不會自動公開店家。
本次沒有變更 Firestore rules；新欄位由 callable server SDK 寫入。

## Web／PWA 設定（尚未啟用）
需使用者提供獨立受限 Google Maps JavaScript API key 與 JavaScript Map ID，並由使用者決定開通 API/計費。
不沿用 Firebase API key，不將實際金鑰寫入原始碼。

```
flutter build web --dart-define=GOOGLE_MAPS_WEB_API_KEY=YOUR_RESTRICTED_WEB_KEY --dart-define=GOOGLE_MAPS_MAP_ID=YOUR_JAVASCRIPT_MAP_ID
```

只在使用者進地圖頁後載入 Google script，不在首頁啟動預載。使用 advanced markers/marker library。未提供設定時保留店家列表並提示未啟用。
限制 key 可用網站來源及 API，設定每日 quota、監控和預算通知；通知不等於停止收費。不要把測試用 DEMO_MAP_ID 當正式設定。
需要正式網域的使用條款/隱私聲明符合所選地圖服務要求。

## 原生 Android／iOS
套件已加入，但本次未寫入任何原生金鑰，也未驗證原生建置。
原生需依官方套件文件配置受限的 Android/iOS 金鑰、各平台 Map ID、開通對應 Maps SDK，完成後使用 `--dart-define=GOOGLE_MAPS_NATIVE_READY=true --dart-define=GOOGLE_MAPS_MAP_ID=...`。
未設定時原生保留列表，不建立缺金鑰的地圖。Windows/Linux/macOS 原生目前不支援內嵌地圖，保留列表；桌面請使用 Web/PWA。

## 部署與驗收
- Functions：只新增 saveShopMapLocation；由使用者處理部署。
- Hosting：以地圖參數重新建置後發布。
- Rules/indexes/Storage：無變更。
- 店主確認公開店家的真實座標後，驗證標記位置、地圖費用事件、來源限制、手機互動。
- 沒有金鑰與實際座標，測試不能當成實際 Google 地圖驗收。單元測試使用替代畫布，不連 Google。
- `tool/shop_map_web_compile_check.dart` 僅供地圖整合的獨立 Web 編譯，沒有 key 不會載入付費地圖。

官方文件：https://pub.dev/packages/google_maps_flutter 、https://pub.dev/packages/google_maps_flutter_web 、https://developers.google.com/maps/billing-and-pricing/manage-costs
