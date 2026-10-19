# 木質暖心小屋 V1 — 圖片生成紀錄

使用內建 image_gen 真正生成，2026-10-18。以使用者附圖的左上木質小屋為材質與品質參考；圖片不包含店家名稱、編號、狀態、統計或操作按鈕。Flutter 疊加全部動態內容。

專案素材位於 `assets/images/shop_house/warm_wood/`。

本目錄 PNG 為 Flutter Widget 渲染截圖，使用測試資料，並非正式店家資料或瀏覽器截圖。可設定 `PETNEST_HOUSE_PREVIEW` 為輸出目錄後執行 `flutter test --no-pub test/my_shop_home_carousel_test.dart` 重新產生。

## 屋頂與空白招牌 — roof_wide.png

Use case: stylized-concept. Create a production transparent PNG architectural decoration ASSET, based on the user's attached PetNest reference's warm wooden cat inn (upper left). ONLY an isolated wide front-facing gabled roof and eaves, no full house, no UI. Beautiful detailed honey oak timber shingles, substantial layered beams, carved wooden joinery, small chimney on left, a few delicate ivy tendrils, warm brass lantern hanging at each far end. Center under ridge has a hanging BLANK pale wooden signboard, absolutely no lettering. Straight-on orthographic elevation, symmetrical overall. Roof spans full width with generous steep triangular gable and richly detailed wooden infill. Composition landscape 3:1, roof and sign fill canvas tightly, all space outside asset genuinely transparent. Premium cozy artisanal architectural illustration, textured painterly realism, soft natural light, warm amber oak, muted greens. NO text, numbers, cats, buttons, statistics, interface, background wall or floor. Asset will overlay Flutter interface, don't generate reference screenshot. Use attached reference for material and quality.

## 手機屋頂 — roof_phone.png

以生成的屋頂素材為編輯參考：

Create a COMPACT mobile variant of this roof asset, same wood and fine painterly material style, transparency, ivy, warm lanterns, chimney, blank hanging wood sign. Make a steep gabled roof for a narrow cottage, target overall width:height ratio exactly 1.8:1. Signboard should occupy 48% overall width and be generous enough for overlaid store name. Maintain frontal elevation and architectural realism. Remove extra horizontal beams on wings and shorten roof wings so it looks naturally vertical and compact, do not horizontally squeeze image. No wall, cat, floor, interface or text. True transparent background. Fill canvas tightly with asset.

## 展示窗 — window.png

Use case: stylized-concept. Production transparent PNG asset for a premium warm wooden cat inn Flutter UI. Match user's attached reference: textured honey oak, softly realistic hand-painted architectural illustration, muted foliage, golden lanterns. Draw ONLY an isolated front-facing square timber WINDOW FRAME, with a completely transparent rectangular opening taking the central 72% width and 72% height. Thick lovingly detailed oak posts, projecting wooden windowsill at bottom, modest amber brass lantern mounted on left post, delicate ivy and small white flowers at bottom right. No glass, NO cat, NO interior, NO wall, NO scenery inside opening. The opening MUST be genuine transparency so a store photo can show through. Frame outer bounds nearly fill square canvas. No text, signs, numerals, UI, buttons. Straight-on elevation, not isometric. Soft natural light, refined material realism. Transparent outside too.

## 植栽 — plants.png

Use case: stylized-concept. Create isolated botanical decorative cutout for a warm timber cat inn interface. Premium soft realistic painterly illustration matching attached PetNest reference, honey oak, muted sage greens, cream blossoms, warm terracotta. A richly detailed cluster: two terracotta pots with lush green leaves and tiny ivory flowers, a slim climbing ivy branch rising on the left to twice pot height, a small brass lantern with amber glow tucked amongst foliage. Composition vertical approximately 2:3, all objects grounded at same bottom line, tightly framed. True transparent background, no ground plane, no house, no text, no sign, no UI, no borders. Refined natural detail, not flat vector or childish cartoon.

## 預設貓咪 — cat_default.png

Use case: stylized-concept. Default cat display image for premium pet inn window. Close-up straight-on portrait of a beautiful grey-and-white tabby cat resting its two paws on a honey oak wooden windowsill, large calm amber-green eyes looking at viewer. Behind cat a softly glowing warm cream interior, golden tiny bokeh lamps and linen curtain edges. Sophisticated softly realistic painterly illustration, richly detailed fur, gentle natural light, warm wood tones and restrained sage palette. Square composition, cat face central and paws near bottom, no external window frame because UI adds separate frame overlay. Match the cozy premium cat inn mood of user's attached reference. No text, logo, numbers, signage, UI, borders, watermark.

## 木質平台 — base.png

Use case stylized-concept. Production UI decorative asset: ONE isolated wide horizontal honey oak wooden raised platform/plinth for a warm cat inn facade. Front-facing orthographic elevation, beautiful realistic painterly wood grain, bevelled rounded corners, two layered planks giving visible depth and delicate joinery. Overall width:height ratio about 12:1, tightly fill wide landscape canvas, no perspective vanishing points, level top surface. A few tiny moss leaves at far edges only. Premium warm natural material quality matching cozy wooden cat inn reference. Genuine transparent background outside platform. No house, plants above, cat, text, signage, UI, buttons or background.

平台輸出另以本機無損 PNG 裁切去除上下透明留白（原圖 2172×724，取 x=0、y=220、w=2172、h=285）；保留 alpha，沒有重繪內容。Flutter 使用九宮格保留平台邊角與厚度。其他素材依原始比例顯示。
