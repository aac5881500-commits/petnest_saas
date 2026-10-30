// 功能：服務展示整組風格與排版獨立、共用尺寸、既有模組條件及草稿儲存的局部回歸。
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_service_showcase.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_service_showcase.dart';
import 'package:petnest_saas/features/shop/widgets/about/service_builtin_artwork.dart';

void main() {
  test('服務卡片尺寸可讀寫，舊值與未知值回退中尺寸', () {
    for (final size in ShopServiceShowcase.cardSizes.keys) {
      final value = const ShopServiceShowcase().copyWith(cardSize: size);
      expect(ShopServiceShowcase.fromMap(value.toMap()).cardSize, size);
      expect(value.copyWith(artworkStyle: 'sticker').cardSize, size);
      expect(value.copyWith(cardLayout: 'list').cardSize, size);
    }
    expect(ShopServiceShowcase.fromMap({}).cardSize, 'medium');
    expect(ShopServiceShowcase.fromMap({'cardSize': 'bad'}).cardSize, 'medium');
  });
  test('四風格三排版讀寫獨立，切換不清空舊圖片或服務勾選', () {
    for (final visual in ShopServiceShowcase.artworkStyles.keys) {
      for (final layout in ShopServiceShowcase.cardLayouts.keys) {
        final value = ShopServiceShowcase(
          layout: 'cards',
          selected: const ['cat_hotel'],
          artworkStyle: visual,
          cardLayout: layout,
          images: const {
            'cat_hotel': {'source': 'platform', 'assetId': 'legacy-card'},
          },
        );
        final loaded = ShopServiceShowcase.fromMap(value.toMap());
        expect(loaded.toMap(), value.toMap());
        expect(loaded.copyWith(artworkStyle: 'sticker').cardLayout, layout);
        expect(loaded.copyWith(cardLayout: 'list').artworkStyle, visual);
        expect(loaded.copyWith(artworkStyle: 'simple').images, value.images);
      }
    }
    expect(ShopServiceShowcase.fromMap({}).layout, 'hidden');
    expect(ShopServiceShowcase.fromMap({}).artworkStyle, 'simple');
    expect(
      ShopServiceShowcase.fromMap({'layout': 'icons'}).artworkStyle,
      'simple',
    );
    expect(
      ShopServiceShowcase.fromMap({'layout': 'cards'}).artworkStyle,
      'postcard',
    );
    expect(
      ShopServiceShowcase.fromMap({'layout': 'editorial'}).cardLayout,
      'list',
    );
    expect(
      ShopServiceShowcase.fromMap({
        'layout': 'cards',
        'cardLayout': 'grid',
        'artworkStyle': 'bad',
      }).artworkStyle,
      'simple',
    );
  });
  testWidgets('兩組卡通與照片均已打包且五服務取不同場景', (tester) async {
    for (final path in ServiceBuiltinArtwork.assets.values) {
      final image = await tester.runAsync(() async {
        final bytes = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      });
      expect(image, isNotNull);
      expect(image!.width / image.height, closeTo(1.5, .01));
      final rects = <Rect>[];
      for (final cell in ServiceBuiltinArtwork.serviceCells.values) {
        final rect = ServiceAtlasPainter(
          image: image,
          cell: cell,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ).cellRect;
        expect(rects.any((r) => r.overlaps(rect)), isFalse);
        rects.add(rect);
      }
      image.dispose();
    }
  });
  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets('四風格共用三排版尺寸與說明，寬度$width無溢出', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final layout in ShopServiceShowcase.cardLayouts.keys) {
        Size? originalCard, originalSlot;
        for (final visual in ShopServiceShowcase.artworkStyles.keys) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AboutServiceShowcaseSection(
                    value: ShopServiceShowcase(
                      layout: 'cards',
                      selected: ShopServiceShowcase.labels.keys.toList(),
                      cardLayout: layout,
                      artworkStyle: visual,
                      images: const {
                        'cat_hotel': {
                          'source': 'builtin',
                          'variant': 'storybook',
                        },
                      },
                    ),
                    enabledModules: const [
                      'cat_hotel',
                      'grooming',
                      'hospital',
                      'store',
                    ],
                    theme: HomeThemeModel.modernDefault,
                    style: const EnvironmentIntroStyle(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final card = tester.getSize(
            find.byKey(const ValueKey('about-service-module-cat_hotel')),
          );
          final slot = tester.getSize(
            find.byKey(const ValueKey('service-image-slot-cat_hotel')),
          );
          originalCard ??= card;
          originalSlot ??= slot;
          expect(card, originalCard);
          expect(slot, originalSlot);
          expect(
            find.text(ShopServiceShowcase.descriptions['cat_hotel']!),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('about-service-module-dog_hotel')),
            findsNothing,
          );
          final artwork = tester.widgetList<ServiceBuiltinArtwork>(
            find.byType(ServiceBuiltinArtwork),
          );
          expect(artwork.length, 4);
          expect(artwork.every((w) => w.variant == visual), isTrue);
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
  testWidgets('只有整組四風格和三排版，切換互不影響、沒有單項換圖', (tester) async {
    var value = const ShopServiceShowcase(
      layout: 'cards',
      selected: ['cat_hotel', 'grooming'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, refresh) => AboutServiceShowcaseEditor(
                value: value,
                enabledModules: const ['cat_hotel', 'grooming'],
                onChanged: (next) => refresh(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ChoiceChip), findsNWidgets(10));
    expect(find.text('更換圖片'), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);
    final dog = find.byKey(const ValueKey('module-showcase-select-dog_hotel'));
    expect(tester.widget<CheckboxListTile>(dog).onChanged, isNull);
    for (final layout in ShopServiceShowcase.cardLayouts.keys) {
      await tester.tap(find.byKey(ValueKey('service-layout-$layout')));
      await tester.pump();
      for (final visual in ShopServiceShowcase.artworkStyles.keys) {
        await tester.tap(find.byKey(ValueKey('service-visual-$visual')));
        await tester.pump();
        expect(value.cardLayout, layout);
        expect(value.artworkStyle, visual);
        expect(value.selected, ['cat_hotel', 'grooming']);
      }
    }
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(value.layout, 'hidden');
    expect(value.cardLayout, 'horizontal');
    expect(value.artworkStyle, 'sticker');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(value.layout, 'cards');
    expect(value.cardLayout, 'horizontal');
    expect(value.artworkStyle, 'sticker');
  });
  testWidgets('關於我們儲存整組風格與排版，不自動發布草稿', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writes = <Map<String, dynamic>>[];
    final shop = <String, dynamic>{
      'name': '測試店家',
      'aboutDescription': '店家介紹',
      'enabledModules': ['cat_hotel'],
      'homeAppearance': {
        'aboutPage': {
          'moduleShowcase': {
            'layout': 'cards',
            'selected': ['cat_hotel'],
            'artworkStyle': 'postcard',
            'cardLayout': 'grid',
          },
        },
      },
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
    await tester.tap(find.byKey(const ValueKey('service-visual-storybook')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('service-layout-list')));
    await tester.pump();
    expect(writes, isEmpty);
    final state =
        tester.state(find.byType(ShopAboutManagePage))
            as ShopDashboardLeaveAware;
    expect(state.dashboardHasUnsavedChanges, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, '儲存').first);
    await tester.pumpAndSettle();
    expect(
      writes.single['homeAppearance.aboutPage.moduleShowcase.artworkStyle'],
      'storybook',
    );
    expect(
      writes.single['homeAppearance.aboutPage.moduleShowcase.cardLayout'],
      'list',
    );
    expect(state.dashboardHasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });
}
