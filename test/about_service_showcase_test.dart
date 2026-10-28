import 'package:petnest_saas/features/shop/widgets/about/service_builtin_artwork.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/shop_service_showcase.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_service_showcase.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_intro_view.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

void main() {
  test('內建風格與個別服務選擇可保存，未知風格回退簡約', () {
    final value = const ShopServiceShowcase(
      layout: 'icons',
      selected: ['cat_hotel'],
      artworkStyle: 'storybook',
    ).withImage('cat_hotel', {'source': 'builtin', 'variant': 'sticker'});
    final saved = ShopServiceShowcase.fromMap(value.toMap());
    expect(saved.artworkStyle, 'storybook');
    expect(saved.imageFor('cat_hotel'), {
      'source': 'builtin',
      'variant': 'sticker',
    });
    expect(
      saved.copyWith(layout: 'overlay').imageFor('cat_hotel'),
      saved.imageFor('cat_hotel'),
    );
    expect(
      ShopServiceShowcase.fromMap({'artworkStyle': 'unknown'}).artworkStyle,
      'simple',
    );
  });
  testWidgets('服務圖片設定僅提供內建與圖庫，不提供店家照片、相簿與上傳', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AboutServiceShowcaseEditor(
              value: const ShopServiceShowcase(
                layout: 'icons',
                selected: ['cat_hotel'],
              ),
              enabledModules: const ['cat_hotel'],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    final expansion = find.byKey(
      const PageStorageKey('service-image-cat_hotel'),
    );
    await tester.ensureVisible(expansion);
    await tester.tap(find.text('貓咪旅店：圖片設定'));
    await tester.pumpAndSettle();
    expect(find.text('選擇圖庫卡片圖片'), findsOneWidget);
    expect(find.text('上傳真實照片'), findsNothing);
    expect(find.text('選擇店家照片'), findsNothing);
    expect(find.text('使用環境相簿第一張'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('四組內建風格每種服務均可顯示，個別選擇優先', (tester) async {
    for (final variant in ShopServiceShowcase.artworkStyles.keys) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AboutServiceShowcaseSection(
              value: ShopServiceShowcase(
                layout: 'icons',
                selected: ShopServiceShowcase.labels.keys.toList(),
                artworkStyle: variant,
              ),
              enabledModules: ShopServiceShowcase.labels.keys.toList(),
              theme: HomeThemeModel.modernDefault,
              style: const EnvironmentIntroStyle(),
            ),
          ),
        ),
      );
      final artworks = tester.widgetList<ServiceBuiltinArtwork>(
        find.byType(ServiceBuiltinArtwork),
      );
      expect(artworks.length, 5);
      expect(artworks.every((a) => a.variant == variant), isTrue);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutServiceShowcaseSection(
            value:
                const ShopServiceShowcase(
                  layout: 'icons',
                  selected: ['cat_hotel'],
                  artworkStyle: 'storybook',
                ).withImage('cat_hotel', {
                  'source': 'builtin',
                  'variant': 'sticker',
                }),
            enabledModules: const ['cat_hotel'],
            theme: HomeThemeModel.modernDefault,
            style: const EnvironmentIntroStyle(),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<ServiceBuiltinArtwork>(find.byType(ServiceBuiltinArtwork))
          .variant,
      'sticker',
    );
  });

  testWidgets('完整關於我們正式頁與預覽均傳入相同服務外觀和照片來源', (tester) async {
    final showcase = const ShopServiceShowcase(
      layout: 'editorial',
      selected: ['cat_hotel'],
      shape: 'soft',
    ).withImage('cat_hotel', {'source': 'firstGallery'});
    final shop = <String, dynamic>{
      'enabledModules': ['cat_hotel'],
    };
    for (final preview in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AboutIntroView(
              shop: shop,
              setting: AboutPageSetting.fromMap({
                'moduleShowcase': showcase.toMap(),
                'cover': {'source': 'none'},
              }),
              theme: HomeThemeModel.modernDefault,
              preview: preview,
            ),
          ),
        ),
      );
      await tester.pump();
      final service = tester.widget<AboutServiceShowcaseSection>(
        find.byType(AboutServiceShowcaseSection),
      );
      expect(service.value.toMap(), showcase.toMap());
      expect(service.shop, same(shop));
      expect(tester.takeException(), isNull);
    }
  });

  test('服務照片與造型讀寫，切換版型保留照片引用且不影響模組限制', () {
    final draft =
        const ShopServiceShowcase(
          layout: 'photoGrid',
          selected: ['cat_hotel', 'dog_hotel'],
          shape: 'rounded',
          imageFit: 'contain',
          imagePosition: 'top',
        ).withImage('cat_hotel', {
          'source': 'platform',
          'assetId': 'card-123',
          'url': '',
        });
    final restored = ShopServiceShowcase.fromMap(draft.toMap());
    expect(restored.toMap(), draft.toMap());
    for (final layout in ShopServiceShowcase.layouts.keys) {
      final changed = restored.copyWith(layout: layout);
      expect(changed.imageFor('cat_hotel')['assetId'], 'card-123');
      expect(changed.shape, 'rounded');
      expect(
        changed.visibleModules(['cat_hotel']),
        layout == 'hidden' ? [] : ['cat_hotel'],
      );
    }
    final bad = ShopServiceShowcase.fromMap({
      'layout': 'unknown',
      'shape': 'unknown',
      'imagePosition': 'bad',
      'images': {'bad': {}, 'cat_hotel': 1},
    });
    expect(bad.layout, 'hidden');
    expect(bad.shape, 'theme');
    expect(bad.imagePosition, 'center');
    expect(bad.images, isEmpty);
  });
  testWidgets('服務照片來源與顯示設定傳入共用圖片元件，移除後回復圖示', (tester) async {
    Future<void> render(ShopServiceShowcase setting) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutServiceShowcaseSection(
            value: setting,
            enabledModules: const ['cat_hotel'],
            shop: const {},
            theme: HomeThemeModel.modernDefault,
            style: const EnvironmentIntroStyle(),
          ),
        ),
      ),
    );
    final value = const ShopServiceShowcase(
      layout: 'photoGrid',
      selected: ['cat_hotel'],
      imageFit: 'contain',
      imagePosition: 'bottom',
    ).withImage('cat_hotel', {'source': 'firstGallery'});
    await render(value);
    final image = tester.widget<AboutMediaView>(find.byType(AboutMediaView));
    expect(image.media.source, 'firstGallery');
    expect(image.fit, BoxFit.contain);
    expect(image.alignment, Alignment.bottomCenter);
    await render(value.withImage('cat_hotel', {'source': 'none'}));
    expect(
      tester.widget<AboutMediaView>(find.byType(AboutMediaView)).media.source,
      'none',
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'previous choices move to About without overwriting its own settings',
    () {
      final shop = <String, dynamic>{
        'enabledModules': ['grooming'],
        'environmentIntro': {
          'environmentPresentation': {
            'moduleShowcase': {
              'layout': 'cards',
              'selected': ['grooming'],
            },
          },
        },
      };
      expect(AboutPageSetting.fromShop(shop).serviceShowcase.selected, [
        'grooming',
      ]);
      expect(ShopIntroContent.environment(shop), isFalse);
      expect(ShopIntroContent.about(shop), isTrue);
      shop['homeAppearance'] = {
        'aboutPage': {
          'moduleShowcase': {'layout': 'hidden', 'selected': []},
        },
      };
      expect(AboutPageSetting.fromShop(shop).serviceShowcase.layout, 'hidden');
      expect(ShopIntroContent.about(shop), isFalse);
    },
  );
  test(
    'closed modules remain hidden and old shops default to no service display',
    () {
      expect(AboutPageSetting.fromShop({}).serviceShowcase.layout, 'hidden');
      const v = ShopServiceShowcase(
        layout: 'icons',
        selected: ['cat_hotel', 'grooming'],
      );
      expect(
        v.visibleModules(
          serviceShowcaseEnabledModules({
            'enabledModules': ['cat_hotel'],
          }),
        ),
        ['cat_hotel'],
      );
      expect(v.visibleModules(['basic_info', 'reports']), isEmpty);
    },
  );
  for (final width in [320.0, 390.0, 1200.0]) {
    for (final layout in ShopServiceShowcase.layouts.keys.where(
      (id) => id != 'hidden',
    )) {
      testWidgets('$layout introduction fits $width and omits closed modules', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AboutServiceShowcaseSection(
                  value: ShopServiceShowcase(
                    layout: layout,
                    selected: ShopServiceShowcase.labels.keys.toList(),
                  ),
                  enabledModules: const [
                    'cat_hotel',
                    'grooming',
                    'hospital',
                    'store',
                  ],
                  theme: HomeThemeModel.classicDefault,
                  style: const EnvironmentIntroStyle(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('about-service-module-cat_hotel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('about-service-module-dog_hotel')),
          findsNothing,
        );
        expect(find.text('服務項目'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('service choices are edited and saved within About', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writes = <Map<String, dynamic>>[];
    final shop = <String, dynamic>{
      'name': '測試店家',
      'aboutDescription': '店家介紹',
      'enabledModules': ['cat_hotel', 'grooming'],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'fixture',
          shopStream: Stream.value(shop),
          saveAbout: (v) async => writes.add(v),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, '服務項目'));
    await tester.pumpAndSettle();
    final dog = find.byKey(const ValueKey('module-showcase-select-dog_hotel'));
    expect(tester.widget<CheckboxListTile>(dog).onChanged, isNull);
    await tester.tap(
      find.byKey(const ValueKey('module-showcase-layout-cards')),
    );
    await tester.pumpAndSettle();
    final grooming = find.byKey(
      const ValueKey('module-showcase-select-grooming'),
    );
    await tester.ensureVisible(grooming);
    await tester.pumpAndSettle();
    await tester.tap(grooming);
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    final state =
        tester.state(find.byType(ShopAboutManagePage))
            as ShopDashboardLeaveAware;
    expect(state.dashboardHasUnsavedChanges, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, '儲存').first);
    await tester.pumpAndSettle();
    expect(
      writes.single['homeAppearance.aboutPage.moduleShowcase.layout'],
      'cards',
    );
    expect(writes.single['homeAppearance.aboutPage.moduleShowcase.selected'], [
      'grooming',
    ]);
    expect(state.dashboardHasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('environment editor no longer exposes a service template tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShopEnvironmentManagePage(
          shopId: 'fixture',
          loadShop: () async => {'environmentIntro': {}},
          saveIntro: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, '服務項目'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
