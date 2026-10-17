import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/features/shop/theme/home_color_palette.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_color_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/shop_app_backdrop.dart';

void main() {
  final Uint8List pngBytes = Uint8List.fromList(<int>[
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    13,
    73,
    68,
    65,
    84,
    120,
    156,
    99,
    248,
    207,
    192,
    80,
    15,
    0,
    4,
    133,
    1,
    128,
    132,
    169,
    140,
    33,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ]);

  HomeThemeModel imageTheme() {
    return HomeThemeModel.modernDefault.copyWith(
      appBackgroundMode: ShopAppBackground.modeImage,
      appBackgroundAssetId: 'bg-1',
      appBackgroundFit: ShopAppBackground.fitContain,
      appBackgroundAlign: ShopAppBackground.alignTop,
      appBackgroundScrim: 0,
    );
  }

  test('舊主題沒有背景欄位時維持純色', () {
    final HomeThemeModel theme = HomeThemeModel.fromMap(<String, dynamic>{
      'backgroundColor': 0xFFFFF8F3,
    }, fallback: HomeThemeModel.modernDefault);
    expect(theme.appBackgroundMode, ShopAppBackground.modeColor);
    expect(theme.appBackgroundAssetId, isEmpty);
    expect(theme.usesAppBackgroundImage, isFalse);
    expect(theme.backgroundColorValue, 0xFFFFF8F3);
    expect(theme.toMap().containsKey('appBackgroundMode'), isFalse);
  });

  test('背景圖片設定可儲存，切回純色仍保留引用', () {
    final Map<String, dynamic> map = imageTheme().toMap();
    final HomeThemeModel loaded = HomeThemeModel.fromMap(
      map,
      fallback: HomeThemeModel.modernDefault,
    );
    expect(loaded.appBackgroundAssetId, 'bg-1');
    expect(loaded.appBackgroundFit, ShopAppBackground.fitContain);
    expect(loaded.appBackgroundAlign, ShopAppBackground.alignTop);
    expect(loaded.appBackgroundScrim, 0);
    final HomeThemeModel solid = loaded.copyWith(
      appBackgroundMode: ShopAppBackground.modeColor,
    );
    expect(solid.usesAppBackgroundImage, isFalse);
    expect(solid.appBackgroundAssetId, 'bg-1');
    final HomeThemeModel again = HomeThemeModel.fromMap(
      solid.toMap(),
      fallback: HomeThemeModel.modernDefault,
    );
    expect(again.appBackgroundMode, ShopAppBackground.modeColor);
    expect(again.appBackgroundAssetId, 'bg-1');
  });

  test('快速配色與恢復預設色彩不清除背景圖片', () {
    final HomeThemeModel current = imageTheme();
    final HomeThemeModel styled = HomeColorPalette.presets
        .firstWhere((HomeColorPreset item) => item.id == 'creamWhite')
        .apply(current);
    expect(styled.backgroundColorValue, 0xFFFFF9F0);
    expect(styled.appBackgroundAssetId, 'bg-1');
    expect(styled.appBackgroundMode, ShopAppBackground.modeImage);
    final HomeThemeModel restored = HomeThemeModel.modernDefault
        .copyWith()
        .withBackdropFrom(current);
    expect(
      restored.primaryColorValue,
      HomeThemeModel.modernDefault.primaryColorValue,
    );
    expect(restored.appBackgroundAssetId, 'bg-1');
    expect(restored.appBackgroundFit, ShopAppBackground.fitContain);
  });

  testWidgets('快速配色可收合，背景選項不提供上傳', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    HomeThemeModel current = imageTheme();
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
    expect(find.text('櫻花粉'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('home-quick-palette-header')),
    );
    await tester.pump();
    expect(find.text('櫻花粉'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('home-quick-palette-header')),
    );
    await tester.pump();
    expect(find.text('櫻花粉'), findsNothing);

    expect(find.text('上傳'), findsNothing);
    expect(find.text('相機'), findsNothing);
    expect(find.text('選擇背景圖片'), findsNothing);
    await tester.ensureVisible(find.text('App 整體背景'));
    await tester.tap(find.text('App 整體背景'));
    await tester.pump();
    await tester.tap(find.text('圖庫圖片'));
    await tester.pump();
    expect(current.appBackgroundMode, ShopAppBackground.modeImage);
    expect(current.appBackgroundAssetId, 'bg-1');
    expect(find.text('更換圖片'), findsOneWidget);
    expect(find.text('上傳'), findsNothing);

    await tester.tap(find.text('完整顯示'));
    await tester.pump();
    expect(current.appBackgroundFit, ShopAppBackground.fitContain);
    await tester.tap(find.text('靠下'));
    await tester.pump();
    expect(current.appBackgroundAlign, ShopAppBackground.alignBottom);
    expect(current.appBackgroundAssetId, 'bg-1');
    await tester.tap(find.text('改回純色'));
    await tester.pump();
    expect(current.appBackgroundMode, ShopAppBackground.modeColor);
    expect(current.appBackgroundAssetId, 'bg-1');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              HomeColorSettingsPanel(
                theme: current,
                entryTheme: HomeThemeModel.modernDefault,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('背景圖失效時退回純色，有效圖片使用指定裁切', (WidgetTester tester) async {
    final MemoryImage memory = MemoryImage(Uint8List.fromList(pngBytes));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopAppBackdrop(
            theme: imageTheme(),
            assetOverride: _asset(enabled: false),
            imageProvider: memory,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopAppBackdrop(
            theme: imageTheme().copyWith(
              appBackgroundFit: ShopAppBackground.fitCover,
              appBackgroundAlign: ShopAppBackground.alignBottom,
            ),
            assetOverride: _asset(),
            imageProvider: memory,
          ),
        ),
      ),
    );
    await tester.pump();
    final Image image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.bottomCenter);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopAppBackdrop(
            theme: imageTheme(),
            assetOverride: _asset(
              category: PlatformMediaCategories.dailyCarePage,
            ),
            imageProvider: memory,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopAppBackdrop(
            theme: imageTheme(),
            assetOverride: _asset(
              category: PlatformMediaCategories.dailyCareCard,
            ),
            imageProvider: memory,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('純色模式不疊圖片', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShopAppBackdrop(theme: HomeThemeModel.modernDefault),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

PlatformMediaAsset _asset({
  bool enabled = true,
  String category = PlatformMediaCategories.appBackground,
}) {
  return PlatformMediaAsset(
    id: 'bg-1',
    name: '暖色背景',
    category: category,
    imageUrl: 'https://example.com/app-bg.jpg',
    thumbnailUrl: 'https://example.com/app-bg.jpg',
    storagePath: 'platform/media_library/bg-1/original.jpg',
    width: 900,
    height: 1600,
    fileBytes: 1200,
    sortOrder: 0,
    enabled: enabled,
  );
}
