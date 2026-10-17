import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/theme/home_color_palette.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_color_settings_panel.dart';

void main() {
  test('舊資料缺少新欄位時保持不透明並推算次要文字', () {
    final HomeThemeModel theme = HomeThemeModel.fromMap(<String, dynamic>{
      'backgroundColor': 0xFFFFFBF7,
      'cardColor': 0xFFFFFFFF,
      'cardBorderColor': 0xFFFFD9B3,
      'primaryColor': 0xFFFF8A00,
      'textColor': 0xFF3A2A20,
    }, fallback: HomeThemeModel.modernDefault);
    expect(theme.secondaryTextColorValue, isNull);
    expect(theme.buttonFollowsPrimary, isTrue);
    expect(theme.buttonTextMode, 'auto');
    expect(theme.backgroundColor.a, 1);
    expect(theme.toMap().containsKey('secondaryTextColor'), isFalse);
    expect(HomeColorContrast.pageNeedsAttention(theme), isFalse);
    final HomeThemeModel pale = theme.copyWith(
      textColorValue: 0xFFFFFBF7,
      backgroundColorValue: 0xFFFFFBF7,
      cardColorValue: 0xFFFFFBF7,
    );
    expect(HomeColorContrast.pageNeedsAttention(pale), isTrue);
  });

  test('快速主題套用後可辨識，改一個顏色就變成自訂', () {
    final HomeThemeModel applied = HomeColorPalette.presets
        .firstWhere((HomeColorPreset item) => item.id == 'sakura')
        .apply(HomeThemeModel.modernDefault);
    expect(HomeColorPalette.matching(applied)?.name, '櫻花粉');
    expect(applied.primaryColorValue, 0xFFE06B84);
    final HomeThemeModel tweaked = applied.copyWith(
      primaryColorValue: 0xFF112233,
    );
    expect(HomeColorPalette.matching(tweaked), isNull);
    expect(HomeColorPalette.presets, hasLength(15));
    expect(
      HomeColorPalette.presets.map((HomeColorPreset item) => item.id),
      containsAll(<String>[
        'warmCream',
        'sakura',
        'freshBlue',
        'sage',
        'grape',
        'milkTea',
        'minimal',
        'dark',
        'creamWhite',
        'hinoki',
        'mistBlue',
        'apricot',
        'nordic',
        'warmStone',
        'forest',
      ]),
    );
  });

  test('新增主題沿用同一組欄位，文字與按鈕維持可閱讀', () {
    for (final HomeColorPreset preset in HomeColorPalette.presets) {
      final HomeThemeModel theme = preset.apply(HomeThemeModel.modernDefault);
      expect(theme.buttonFollowsPrimary, isTrue, reason: preset.name);
      expect(theme.buttonTextMode, 'auto', reason: preset.name);
      final Color nav = Color.alphaBlend(
        theme.primaryColor.withValues(alpha: 0.12),
        theme.cardColor,
      );
      expect(
        HomeColorContrast.pageNeedsAttention(theme),
        isFalse,
        reason:
            '${preset.name} '
            'text/bg ${HomeColorContrast.ratio(theme.textColor, theme.backgroundColor).toStringAsFixed(2)} '
            'text/card ${HomeColorContrast.ratio(theme.textColor, theme.cardColor).toStringAsFixed(2)} '
            'button ${HomeColorContrast.ratio(theme.buttonForegroundColor, theme.buttonBackgroundColor).toStringAsFixed(2)} '
            'nav ${HomeColorContrast.ratio(theme.primaryColor, nav).toStringAsFixed(2)}',
      );
    }
  });

  test('HEX 只接受正確格式', () {
    expect(
      HomeColorPalette.tryParseHex('#AABBCC', allowAlpha: false),
      0xFFAABBCC,
    );
    expect(
      HomeColorPalette.tryParseHex('#80AABBCC', allowAlpha: true),
      0x80AABBCC,
    );
    expect(HomeColorPalette.tryParseHex('zz', allowAlpha: false), isNull);
    expect(
      HomeColorPalette.tryParseHex('#80AABBCC', allowAlpha: false),
      isNull,
    );
    expect(HomeColorPalette.hexOf(0xFFFFF8F3), '#FFF8F3');
  });

  testWidgets('色彩面板在手機與桌機寬度不溢出，主題可套用', (WidgetTester tester) async {
    Future<void> pump(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      HomeThemeModel current = HomeThemeModel.modernDefault;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return ListView(
                  children: <Widget>[
                    HomeColorSettingsPanel(
                      theme: current,
                      entryTheme: HomeThemeModel.modernDefault,
                      onChanged: (HomeThemeModel value) {
                        setState(() => current = value);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('快速配色'), findsOneWidget);
      expect(find.text('目前套用：自訂配色'), findsOneWidget);
      expect(find.text('目前色彩'), findsNothing);
      expect(find.text('恢復進入時的色彩'), findsOneWidget);
      expect(find.text('奶油暖白'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey<String>('home-quick-palette-header')),
      );
      await tester.pump();
      expect(find.text('奶油暖白'), findsOneWidget);
      final Finder preset = find.text('櫻花粉');
      await tester.ensureVisible(preset);
      await tester.pump();
      await tester.tap(preset);
      await tester.pump();
      expect(current.primaryColorValue, 0xFFE06B84);
      expect(find.text('目前套用：櫻花粉'), findsOneWidget);
      final Finder cream = find.text('奶油暖白');
      await tester.ensureVisible(cream);
      await tester.tap(cream);
      await tester.pump();
      expect(current.backgroundColorValue, 0xFFFFF9F0);
      expect(find.text('目前套用：奶油暖白'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('卡片與外框'), 250);
      await tester.pump();
      await tester.tap(find.text('卡片與外框'));
      await tester.pump();
      final Finder adjust = find.widgetWithText(TextButton, '調整').first;
      await tester.scrollUntilVisible(adjust, 200);
      await tester.pump();
      await tester.tap(adjust);
      await tester.pump();
      expect(find.text('自訂顏色'), findsOneWidget);
      expect(find.text('恢復預設'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(const Size(390, 844));
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(const Size(1280, 900));
  });
}
