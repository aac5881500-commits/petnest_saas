import 'package:petnest_saas/features/shop/widgets/modern_home/home_layout_canvas.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/services/store_home_draft_merge.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/appearance_category_bar.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_front_home_settings_section.dart';

void main() {
  test('canvas store entrance selects its own frontend category', () {
    expect(
      AppearanceCategories.forSection('storeEntrance'),
      AppearanceCategories.store,
    );
    expect(
      AppearanceCategories.of(AppearanceCategories.store).shortLabel,
      '商城入口',
    );
  });
  test(
    'entry draft saves text image and style without overwriting newer products',
    () {
      const loaded = ModernStoreHomeSetting();
      final latest = loaded.copyWith(
        featuredTitle: '最新商品標題',
        showFeaturedProducts: false,
      );
      final draft = loaded.copyWith(
        storeBannerTitle: '貓咪好物',
        storeBannerImageUrl: 'https://example.com/photo.jpg',
        storeBannerImageStoragePath: 'shops/1/home/photo.jpg',
        storeEntryLayout: ModernStoreEntryLayouts.brand,
      );
      final saved = mergeStoreHomeDisplayDraft(
        latest: latest,
        loaded: loaded,
        draft: draft,
      );
      expect(saved.storeBannerTitle, '貓咪好物');
      expect(saved.storeBannerImageUrl, draft.storeBannerImageUrl);
      expect(
        saved.storeBannerImageStoragePath,
        draft.storeBannerImageStoragePath,
      );
      expect(saved.storeEntryLayout, ModernStoreEntryLayouts.brand);
      expect(saved.featuredTitle, '最新商品標題');
      expect(saved.showFeaturedProducts, false);
      final reopened = ModernStoreHomeSetting.fromMap(saved.toMap());
      expect(reopened.storeBannerTitle, draft.storeBannerTitle);
      expect(reopened.storeEntryLayout, draft.storeEntryLayout);
    },
  );
  testWidgets(
    'canvas entrance selects settings instead of navigating into store',
    (tester) async {
      String? selected;
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeLayoutCanvas(
              background: Colors.white,
              sectionIds: const ['storeEntrance'],
              sectionOrder: const ['storeEntrance'],
              spanOf: (_) => HomeSectionSpan.full,
              pinFooter: false,
              shopInfo: null,
              bottomInset: 0,
              selectedSectionId: null,
              onSelectSection: (id) => selected = id,
              onSectionOrderChanged: (_) {},
              focusSectionId: null,
              focusSectionToken: 0,
              buildSection: (id) => id == 'storeEntrance'
                  ? SizedBox(
                      height: 160,
                      child: TextButton(
                        onPressed: () => opened = true,
                        child: const Text('逛逛賣場'),
                      ),
                    )
                  : const SizedBox(height: 40),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.text('逛逛賣場')));
      await tester.pump();
      expect(selected, 'storeEntrance');
      expect(opened, false);
      expect(
        find.byKey(const Key('home-section-drag-storeEntrance')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'frontend entry controls edit supplied draft without loading Firestore',
    (tester) async {
      ModernStoreHomeSetting value = const ModernStoreHomeSetting(
        storeEntryLayout: ModernStoreEntryLayouts.brand,
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
      expect(find.text('商城入口樣式'), findsOneWidget);
      expect(find.text('首頁顯示精選商品'), findsNothing);
      final field = find.widgetWithText(TextField, '卡片標題');
      await tester.ensureVisible(field);
      await tester.enterText(field, '貓咪好物');
      await tester.pump();
      expect(value.storeBannerTitle, '貓咪好物');
      expect(value.storeEntryLayout, ModernStoreEntryLayouts.brand);
      expect(tester.takeException(), isNull);
    },
  );
}
