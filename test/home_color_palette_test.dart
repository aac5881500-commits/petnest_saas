import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/theme/home_color_palette.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_color_settings_panel.dart';

void main() {
  test('舊資料缺少新欄位時保持不透明並推算次要文字', () {
    final HomeThemeModel theme = HomeThemeModel.fromMap(
      <String, dynamic>{
        'backgroundColor': 0xFFFFFBF7,
        'cardColor': 0xFFFFFFFF,
        'cardBorderColor': 0xFFFFD9B3,
        'primaryColor': 0xFFFF8A00,
        'textColor': 0xFF3A2A20,
      },
      fallback: HomeThemeModel.modernDefault,
    );
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
    expect(HomeColorPalette.presets, hasLength(8));
  });

  test('HEX 只接受正確格式', () {
    expect(HomeColorPalette.tryParseHex('#AABBCC', allowAlpha: false), 0xFFAABBCC);
    expect(HomeColorPalette.tryParseHex('#80AABBCC', allowAlpha: true), 0x80AABBCC);
    expect(HomeColorPalette.tryParseHex('zz', allowAlpha: false), isNull);
    expect(HomeColorPalette.tryParseHex('#80AABBCC', allowAlpha: false), isNull);
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
      expect(find.text('主題快速套用'), findsOneWidget);
      final Finder preset = find.text('櫻花粉');
      await tester.ensureVisible(preset);
      await tester.pump();
      await tester.tap(preset);
      await tester.pump();
      expect(current.primaryColorValue, 0xFFE06B84);
      expect(find.text('目前：櫻花粉'), findsOneWidget);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(const Size(390, 844));
    await pump(const Size(1280, 900));
  });
}
