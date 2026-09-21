// 檔案名稱：test/daily_care_title_icon_picker_test.dart
// 功能說明：每日照護小圖示選擇器排版、空狀態、錯誤重試與 BoxFit。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/features/shop/widgets/platform_media_asset_picker.dart';

void main() {
  final Uint8List pngBytes = Uint8List.fromList(const <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  ImageProvider memoryImage(String url) => MemoryImage(pngBytes);

  PlatformMediaAsset icon(String id) {
    return PlatformMediaAsset.fromMap(id, <String, dynamic>{
      'name': '圖示 $id',
      'category': PlatformMediaCategories.dailyCareIcon,
      'imageUrl': 'https://example.invalid/$id.png',
      'enabled': true,
    });
  }

  testWidgets('dailyCareIcon 空狀態文字', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlatformMediaAssetPickerSheet(
          category: PlatformMediaCategories.dailyCareIcon,
          assetsOverride: <PlatformMediaAsset>[],
        ),
      ),
    );
    expect(find.text(PlatformMediaAssetPickerLabels.emptyIcon), findsOneWidget);
    expect(
      find.text(PlatformMediaAssetPickerLabels.emptyGeneral),
      findsNothing,
    );
  });

  testWidgets('其他分類空狀態維持原文字', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlatformMediaAssetPickerSheet(
          category: PlatformMediaCategories.dailyCareCard,
          assetsOverride: <PlatformMediaAsset>[],
        ),
      ),
    );
    expect(
      find.text(PlatformMediaAssetPickerLabels.emptyGeneral),
      findsOneWidget,
    );
  });

  testWidgets('圖庫錯誤顯示重新讀取且不清除 selectedId', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlatformMediaAssetPickerSheet(
          category: PlatformMediaCategories.dailyCareIcon,
          selectedId: 'keep-me',
          errorOverride: 'fail',
        ),
      ),
    );
    expect(find.text(PlatformMediaAssetPickerLabels.loadError), findsOneWidget);
    expect(find.text(PlatformMediaAssetPickerLabels.retry), findsOneWidget);
    final PlatformMediaAssetPickerSheet sheet = tester
        .widget<PlatformMediaAssetPickerSheet>(
          find.byType(PlatformMediaAssetPickerSheet),
        );
    expect(sheet.selectedId, 'keep-me');
    await tester.tap(find.text(PlatformMediaAssetPickerLabels.retry));
    await tester.pump();
    final PlatformMediaAssetPickerSheet after = tester
        .widget<PlatformMediaAssetPickerSheet>(
          find.byType(PlatformMediaAssetPickerSheet),
        );
    expect(after.selectedId, 'keep-me');
    expect(find.text(PlatformMediaAssetPickerLabels.loadError), findsOneWidget);
  });

  testWidgets('dailyCareIcon 使用 contain，背景分類使用 cover', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformMediaAssetPickerSheet(
          category: PlatformMediaCategories.dailyCareIcon,
          assetsOverride: <PlatformMediaAsset>[icon('a')],
          imageProviderBuilder: memoryImage,
        ),
      ),
    );
    await tester.pump();
    final Image iconImage = tester.widget<Image>(find.byType(Image));
    expect(iconImage.fit, BoxFit.contain);
    expect(find.byType(PlatformMediaTransparencyBoard), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformMediaAssetPickerSheet(
          category: PlatformMediaCategories.dailyCarePage,
          assetsOverride: <PlatformMediaAsset>[
            PlatformMediaAsset.fromMap('p', <String, dynamic>{
              'name': '頁背景',
              'category': PlatformMediaCategories.dailyCarePage,
              'imageUrl': 'https://example.invalid/p.jpg',
              'enabled': true,
            }),
          ],
          imageProviderBuilder: memoryImage,
        ),
      ),
    );
    await tester.pump();
    final Image pageImage = tester.widget<Image>(find.byType(Image));
    expect(pageImage.fit, BoxFit.cover);
    expect(find.byType(PlatformMediaTransparencyBoard), findsNothing);
  });

  testWidgets('手機與桌面圖示 Grid 不 overflow', (WidgetTester tester) async {
    final List<PlatformMediaAsset> assets = List<PlatformMediaAsset>.generate(
      12,
      (int i) => icon('i$i'),
    );
    for (final Size size in <Size>[
      const Size(360, 720),
      const Size(1280, 800),
    ]) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            home: SizedBox(
              width: size.width,
              height: size.height,
              child: PlatformMediaAssetPickerSheet(
                category: PlatformMediaCategories.dailyCareIcon,
                assetsOverride: assets,
                imageProviderBuilder: memoryImage,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
