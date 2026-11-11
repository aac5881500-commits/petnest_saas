import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/models/pre_arrival_appearance.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/booking/widgets/pre_arrival_appearance_surface.dart';
import 'package:petnest_saas/features/booking/widgets/pre_arrival_styled_content.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_style_picker.dart';

PreArrivalGuideModel example() => togglePreArrivalCatalog(
  const PreArrivalGuideModel(
    shopId: '',
    serviceType: 'accommodation',
    style: 'packing',
    enabled: true,
  ),
  preArrivalCatalog.first,
  true,
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'legacy maps, customized round trip and style changes retain page appearance',
    () {
      final legacy = PreArrivalGuideModel.fromMap(
        shopId: '',
        serviceType: 'accommodation',
        data: {'style': 'packing'},
      );
      expect(legacy.appearance.isDefault, true);
      expect(legacy.toMap(updatedBy: 'owner').containsKey('appearance'), false);
      final appearance = PreArrivalAppearance.fromMap({
        'fontFamily': 'NotoSerifTC',
        'fontScale': 1.2,
        'colorMode': 'custom',
        'accentColor': 0xff3344aa,
        'backgroundColor': 0xfffafafa,
      });
      final guide = example().copyWith(appearance: appearance);
      final stored = PreArrivalGuideModel.fromMap(
        shopId: '',
        serviceType: 'accommodation',
        data: guide.toMap(updatedBy: 'owner'),
      );
      expect(stored.appearance.toMap(), appearance.toMap());
      expect(
        stored.copyWith(style: 'timeline').appearance.fontFamily,
        'NotoSerifTC',
      );
      expect(
        stored.copyWith(appearance: const PreArrivalAppearance()).blocks.length,
        guide.blocks.length,
      );
      expect(
        PreArrivalAppearance.fromMap({
          'fontFamily': 'bad',
          'fontScale': 100,
          'colorMode': 'bad',
          'textColor': -1,
        }).fontFamily,
        'style',
      );
      expect(PreArrivalAppearance.fromMap({'fontScale': 100}).fontScale, 1.4);
    },
  );
  test(
    'theme palette uses shop colors and custom pale accent uses dark button text',
    () {
      final theme = ShopFrontendTheme.fromHome(
        HomeThemeModel.modernDefault.copyWith(
          primaryColorValue: 0xff2468aa,
          backgroundColorValue: 0xfff3f6fb,
          cardColorValue: 0xffffffff,
        ),
      );
      final follow = PreArrivalPalette.resolve(
        example().copyWith(
          appearance: const PreArrivalAppearance(
            colorMode: 'theme',
            fontFamily: 'theme',
          ),
        ),
        theme,
        'NotoSansTC',
      );
      expect(follow.accent, theme.primaryColor);
      expect(follow.paper, theme.background);
      expect(follow.card, theme.cardColor);
      expect(follow.fontFamily, 'NotoSansTC');
      final custom = PreArrivalPalette.resolve(
        example().copyWith(
          appearance: const PreArrivalAppearance(
            colorMode: 'custom',
            accentColor: 0xfffff0cc,
            textColor: 0xffffffff,
            backgroundColor: 0xffffffff,
            cardColor: 0xffffffff,
          ),
        ),
        theme,
        null,
      );
      expect(custom.onAccent, isNot(Colors.white));
      expect(
        PreArrivalPalette.contrast(custom.ink, custom.paper),
        greaterThanOrEqualTo(4.5),
      );
    },
  );
  testWidgets(
    'more choices starts collapsed and adds new optional item without changing existing text',
    (tester) async {
      var guide = example();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => ListView(
                children: [
                  PreArrivalCatalogPicker(
                    guide: guide,
                    onChanged: (v) => update(() => guide = v),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('catalog-picker-supplements')),
        findsNothing,
      );
      await tester.tap(find.text('更多選擇'));
      await tester.pumpAndSettle();
      final item = find.byKey(const ValueKey('catalog-picker-supplements'));
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(guide.blocks.any((b) => b.id == 'catalog-supplements'), true);
      expect(guide.blocks.any((b) => b.id == 'catalog-food'), true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('appearance editor custom mode and reset preserve checklist', (
    tester,
  ) async {
    var guide = example();
    final before = guide.blocks.map((b) => b.text).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => ListView(
              children: [
                PreArrivalAppearanceEditor(
                  guide: guide,
                  onChanged: (v) => update(() => guide = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('整頁字體與顏色'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('自訂顏色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自訂顏色'));
    await tester.pumpAndSettle();
    expect(guide.appearance.colorMode, 'custom');
    expect(find.text('頁面背景'), findsOneWidget);
    await tester.ensureVisible(find.text('還原本頁字體與顏色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('還原本頁字體與顏色'));
    await tester.pumpAndSettle();
    expect(guide.appearance.isDefault, true);
    expect(guide.blocks.map((b) => b.text).toList(), before);
  });
  for (final style in ['classic', 'packing', 'timeline', 'minimal']) {
    testWidgets(
      '$style applies font, custom colors and larger text at mobile width',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final guide = example().copyWith(
          style: style,
          appearance: const PreArrivalAppearance(
            fontFamily: 'NotoSansTC',
            fontScale: 1.2,
            colorMode: 'custom',
            accentColor: 0xff446688,
            textColor: 0xff222222,
            backgroundColor: 0xfff4f6f8,
            cardColor: 0xffffffff,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(home: PreArrivalGuidePage(guide: guide, embedded: true)),
        );
        await tester.pumpAndSettle();
        final scope = tester.widget<PreArrivalAppearanceScope>(
          find.byType(PreArrivalAppearanceScope),
        );
        expect(scope.palette.fontFamily, 'NotoSansTC');
        expect(scope.palette.accent, const Color(0xff446688));
        if (style != 'classic') {
          final renderer = tester.widget<PreArrivalStyledContent>(
            find.byType(PreArrivalStyledContent),
          );
          expect(renderer.palette!.fontFamily, 'NotoSansTC');
          expect(renderer.palette!.card, Colors.white);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
