// 檔案名稱：test/modern_store_home_setting_test.dart
// 功能說明：新版商城首頁設定的單元測試（舊店家沒有新欄位 → fallback 預設文案）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_store_card.dart';
import 'package:flutter/material.dart';

void main() {
  test('舊店家沒有新欄位 → fallback 預設文案', () {
    final ModernStoreHomeSetting setting = ModernStoreHomeSetting.fromMap(
      const <String, dynamic>{},
    );
    expect(setting.resolvedTitle, '寵物賣場');
    expect(setting.resolvedSubtitle, '精選毛孩好物，把喜歡帶回家');
    expect(setting.resolvedButtonText, '逛逛賣場');
    expect(setting.hasBackgroundImage, isFalse);
    expect(setting.storeBannerOverlayPreset, ModernStoreCardOverlays.none);
    expect(
      setting.storeBannerContentPosition,
      ModernStoreCardPositions.centerLeft,
    );
    expect(
      setting.featuredProductLayout,
      ModernFeaturedProductLayouts.horizontal,
    );
    expect(setting.storeEntryLayout, ModernStoreEntryLayouts.banner);
  });

  test('版型調整不會清掉商城圖片與開關', () {
    const ModernStoreHomeSetting original = ModernStoreHomeSetting(
      storeBannerImageUrl: 'https://cdn.example/store.jpg',
      storeBannerTitle: '毛孩選品',
      showFeaturedProducts: true,
      showStoreBanner: false,
    );
    final ModernStoreHomeSetting next = original.copyWith(
      featuredProductLayout: ModernFeaturedProductLayouts.featured,
      storeEntryLayout: ModernStoreEntryLayouts.brand,
    );
    expect(next.storeBannerImageUrl, original.storeBannerImageUrl);
    expect(next.storeBannerTitle, '毛孩選品');
    expect(next.showFeaturedProducts, isTrue);
    expect(next.showStoreBanner, isFalse);
    expect(
      ModernStoreHomeSetting.fromMap(const <String, dynamic>{
        'featuredProductLayout': 'nope',
        'storeEntryLayout': 'missing',
        'storeBannerImageUrl': 'https://cdn.example/store.jpg',
      }).storeBannerImageUrl,
      'https://cdn.example/store.jpg',
    );
  });

  test('遮罩強度為三段', () {
    expect(
      ModernStoreCardOverlays.opacity(ModernStoreCardOverlays.light),
      0.15,
    );
    expect(
      ModernStoreCardOverlays.opacity(ModernStoreCardOverlays.standard),
      0.30,
    );
    expect(ModernStoreCardOverlays.opacity(ModernStoreCardOverlays.deep), 0.45);
    expect(ModernStoreCardOverlays.opacity(ModernStoreCardOverlays.none), 0);
  });

  test('按鈕文字依背景自動對比', () {
    expect(
      ModernStoreCardButtonColors.foregroundOf(const Color(0xFF2A221C)),
      const Color(0xFFFFFFFF),
    );
    expect(
      ModernStoreCardButtonColors.foregroundOf(const Color(0xFFFFFFFF)),
      const Color(0xFF2A221C),
    );
  });

  testWidgets('入口卡片是整張背景，不是左右兩塊', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ModernHomeStoreCard(
            theme: HomeThemeModel.modernDefault,
            setting: ModernStoreHomeSetting(
              storeBannerTitle: '寵物賣場',
              storeBannerSubtitle: '精選毛孩好物，把喜歡帶回家',
              storeBannerButtonText: '逛逛賣場',
              storeBannerOverlayPreset: ModernStoreCardOverlays.standard,
            ),
          ),
        ),
      ),
    );
    expect(find.text('寵物賣場'), findsOneWidget);
    expect(find.text('逛逛賣場'), findsOneWidget);
    expect(find.byType(Stack), findsWidgets);
    expect(find.byType(Positioned), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('品牌卡與商品櫥窗可以畫出來', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              ModernHomeStoreCard(
                theme: HomeThemeModel.modernDefault,
                setting: ModernStoreHomeSetting(
                  storeEntryLayout: ModernStoreEntryLayouts.brand,
                  storeBannerTitle: '寵物選品',
                ),
              ),
              ModernHomeStoreCard(
                theme: HomeThemeModel.modernDefault,
                setting: ModernStoreHomeSetting(
                  storeEntryLayout: ModernStoreEntryLayouts.showcase,
                ),
                previewChrome: true,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('寵物選品'), findsOneWidget);
    expect(find.byKey(const Key('store-entry-brand')), findsOneWidget);
    expect(find.byKey(const Key('store-entry-showcase')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
