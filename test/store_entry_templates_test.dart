import 'package:petnest_saas/core/models/store_entry_builtin_images.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_entry_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_store_card.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_front_home_settings_section.dart';

void main() {
  testWidgets('all bundled store photos decode as assets without network', (
    tester,
  ) async {
    for (final id in StoreEntryBuiltinImages.assets.keys) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 200,
            child: StoreEntryPhoto(StoreEntryBuiltinImages.url(id)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
      expect(tester.takeException(), isNull, reason: id);
    }
  });
  testWidgets('applying template preserves uploaded photos and storage paths', (
    tester,
  ) async {
    var value = const ModernStoreHomeSetting(
      storeBannerImageUrl: 'https://example.com/one.jpg',
      storeBannerImageStoragePath: 'shops/test/one.jpg',
      storeEntrySecondImageUrl: 'https://example.com/two.jpg',
      storeEntrySecondImageStoragePath: 'shops/test/two.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoreFrontHomeSettingsSection(
              shopId: 'test',
              canManage: true,
              entryOnly: true,
              initialSetting: value,
              onChanged: (next) => value = next,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final target = find.byKey(
      const ValueKey('store-quick-template-layeredPhotos'),
    );
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    expect(value.storeBannerImageUrl, 'https://example.com/one.jpg');
    expect(value.storeEntrySecondImageUrl, 'https://example.com/two.jpg');
    expect(value.storeBannerImageStoragePath, 'shops/test/one.jpg');
    expect(value.storeEntrySecondImageStoragePath, 'shops/test/two.jpg');
    expect(tester.takeException(), isNull);
  });

  test('seven layouts round-trip with both owner photos and custom copy', () {
    expect(ModernStoreEntryLayouts.quickTemplates.length, 7);
    for (final id in ModernStoreEntryLayouts.quickTemplates.keys) {
      final value = ModernStoreHomeSetting(
        storeEntryLayout: id,
        storeBannerTitle: '我的商城',
        storeBannerSubtitle: '店家的文案',
        storeBannerImageUrl: 'https://example.com/one.jpg',
        storeEntrySecondImageUrl: 'https://example.com/two.jpg',
        storeEntrySecondImageStoragePath: 'shops/test/two.jpg',
      );
      final reopened = ModernStoreHomeSetting.fromMap(value.toMap());
      expect(reopened.storeEntryLayout, id);
      expect(reopened.storeBannerTitle, '我的商城');
      expect(reopened.storeEntrySecondImageUrl, value.storeEntrySecondImageUrl);
      expect(
        reopened.storeEntrySecondImageStoragePath,
        value.storeEntrySecondImageStoragePath,
      );
      expect(
        reopened.copyWith(storeBannerTitle: '換標題').storeEntrySecondImageUrl,
        value.storeEntrySecondImageUrl,
      );
    }
  });
  for (final width in [320.0, 390.0, 900.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'seven layouts render and open store at width $width scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final id in ModernStoreEntryLayouts.quickTemplates.keys) {
            var opened = false;
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1800),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ModernHomeStoreCard(
                          theme: HomeThemeModel.modernDefault,
                          setting: ModernStoreHomeSetting(
                            storeEntryLayout: id,
                            storeBannerTitle: '寵物好物商城',
                            storeBannerSubtitle: '貓咪的日常好物',
                          ),
                          onTap: () => opened = true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull, reason: id);
            expect(find.text('寵物好物商城'), findsOneWidget);
            await tester.tap(find.byKey(ValueKey('store-entry-$id')));
            expect(opened, true, reason: id);
          }
        },
      );
    }
  }
  testWidgets('template changes preserve text and expose second photo editor', (
    tester,
  ) async {
    var value = const ModernStoreHomeSetting(
      storeBannerTitle: '店主自訂標題',
      storeBannerSubtitle: '保留這段文字',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: StoreFrontHomeSettingsSection(
                shopId: 'test',
                canManage: true,
                entryOnly: true,
                initialSetting: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final target = find.byKey(
      const ValueKey('store-quick-template-layeredPhotos'),
    );
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    expect(value.storeEntryLayout, ModernStoreEntryLayouts.layeredPhotos);
    expect(value.storeBannerImageUrl, StoreEntryBuiltinImages.url('goods'));
    expect(
      value.storeEntrySecondImageUrl,
      StoreEntryBuiltinImages.url('feather'),
    );
    final reopened = ModernStoreHomeSetting.fromMap(value.toMap());
    expect(reopened.storeBannerImageUrl, value.storeBannerImageUrl);
    expect(reopened.storeEntrySecondImageUrl, value.storeEntrySecondImageUrl);
    expect(reopened.storeBannerImageStoragePath, isEmpty);
    expect(value.storeBannerTitle, '店主自訂標題');
    expect(value.storeBannerSubtitle, '保留這段文字');
    expect(find.text('更換第二張照片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
