// 檔案名稱：test/shop_house_appearance_test.dart
// 功能說明：小屋用途相容舊圖庫，選擇器只顯示對應區域，並可回到預設。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/models/shop_house_appearance.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';
import 'package:petnest_saas/features/shop/widgets/platform_media_asset_picker.dart';

void main() {
  test('舊素材沒有 placements 仍維持原本分類', () {
    final PlatformMediaAsset asset =
        PlatformMediaAsset.fromMap('old', <String, dynamic>{
          'name': '晨光',
          'category': PlatformMediaCategories.dailyCarePage,
          'imageUrl': 'https://example.com/a.jpg',
          'enabled': true,
        });
    expect(asset.placements, isEmpty);
    expect(asset.category, PlatformMediaCategories.dailyCarePage);
    expect(asset.allowsPlacement(ShopHousePlacements.roof), isFalse);
    expect(asset.toMap()['category'], PlatformMediaCategories.dailyCarePage);
  });

  test('小屋素材可同時允許左右裝飾', () {
    final PlatformMediaAsset plant = PlatformMediaAsset.fromMap(
      'plant',
      <String, dynamic>{
        'name': '窗邊植物',
        'category': PlatformMediaCategories.shopHouse,
        'placements': <String>[
          ShopHousePlacements.decorationLeft,
          ShopHousePlacements.decorationRight,
          'not-a-placement',
        ],
        'imageUrl': 'https://example.com/plant.png',
        'enabled': true,
      },
    );
    expect(plant.allowsPlacement(ShopHousePlacements.decorationLeft), isTrue);
    expect(plant.allowsPlacement(ShopHousePlacements.decorationRight), isTrue);
    expect(plant.allowsPlacement(ShopHousePlacements.roof), isFalse);
    expect(plant.placements, hasLength(2));
    expect(
      PlatformMediaLibraryService.normalizePlacements(
        PlatformMediaCategories.shopHouse,
        plant.placements,
      ),
      plant.placements,
    );
    expect(
      () => PlatformMediaLibraryService.normalizePlacements(
        PlatformMediaCategories.shopHouse,
        const <String>[],
      ),
      throwsArgumentError,
    );
    expect(
      PlatformMediaLibraryService.normalizePlacements(
        PlatformMediaCategories.dailyCareIcon,
        const <String>[ShopHousePlacements.roof],
      ),
      isEmpty,
    );
  });

  test('店家選擇只存 assetId，空值就是預設', () {
    final ShopHouseAppearance parsed = ShopHouseAppearance.fromMap(
      <String, dynamic>{'roofAssetId': 'roof-1', 'wallAssetId': '  '},
    );
    expect(parsed.roofAssetId, 'roof-1');
    expect(parsed.wallAssetId, isEmpty);
    expect(parsed.idFor(ShopHousePlacements.windowFrame), isEmpty);
    final ShopHouseAppearance cleared = parsed.withPlacement(
      ShopHousePlacements.roof,
      '',
    );
    expect(cleared.roofAssetId, isEmpty);
    expect(cleared.toMap()['roofAssetId'], isEmpty);
    expect(ShopHouseAppearance.fromMap(null).roofAssetId, isEmpty);
  });

  testWidgets('更換屋頂只列出屋頂素材，點一下不會關閉', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final PlatformMediaAsset roof = PlatformMediaAsset.fromMap(
      'roof-1',
      <String, dynamic>{
        'name': '暖木屋面',
        'category': PlatformMediaCategories.shopHouse,
        'placements': <String>[ShopHousePlacements.roof],
        'imageUrl': 'https://example.invalid/roof.png',
        'enabled': true,
      },
    );
    final PlatformMediaAsset plant = PlatformMediaAsset.fromMap(
      'plant-1',
      <String, dynamic>{
        'name': '左側植物',
        'category': PlatformMediaCategories.shopHouse,
        'placements': <String>[
          ShopHousePlacements.decorationLeft,
          ShopHousePlacements.decorationRight,
        ],
        'imageUrl': 'https://example.invalid/plant.png',
        'enabled': true,
      },
    );
    PlatformMediaPick? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showShopHouseAssetPicker(
                    context: context,
                    placement: ShopHousePlacements.roof,
                    title: '選擇屋頂',
                    assetsOverride: <PlatformMediaAsset>[roof, plant],
                    imageProviderBuilder: (_) => MemoryImage(_png),
                  );
                },
                child: const Text('開啟'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.text('選擇屋頂'), findsOneWidget);
    expect(find.text('PetNest 預設'), findsOneWidget);
    expect(find.text('暖木屋面'), findsOneWidget);
    expect(find.text('左側植物'), findsNothing);
    await tester.tap(find.text('暖木屋面'));
    await tester.pump();
    expect(result, isNull);
    expect(find.text('套用'), findsOneWidget);
    await tester.tap(find.text('套用'));
    await tester.pumpAndSettle();
    expect(result?.asset?.id, 'roof-1');
    expect(result?.usePlatformDefault, isFalse);
  });

  testWidgets('套用 PetNest 預設會清掉選擇', (WidgetTester tester) async {
    PlatformMediaPick? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showShopHouseAssetPicker(
                    context: context,
                    placement: ShopHousePlacements.decorationLeft,
                    title: '選擇左側裝飾',
                    selectedId: 'plant-1',
                    assetsOverride: <PlatformMediaAsset>[
                      PlatformMediaAsset.fromMap('plant-1', <String, dynamic>{
                        'name': '窗邊植物',
                        'category': PlatformMediaCategories.shopHouse,
                        'placements': <String>[
                          ShopHousePlacements.decorationLeft,
                          ShopHousePlacements.decorationRight,
                        ],
                        'imageUrl': 'https://example.invalid/plant.png',
                        'enabled': true,
                      }),
                    ],
                    imageProviderBuilder: (_) => MemoryImage(_png),
                  );
                },
                child: const Text('開啟'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.text('窗邊植物'), findsOneWidget);
    await tester.tap(find.text('PetNest 預設'));
    await tester.pump();
    await tester.tap(find.text('套用'));
    await tester.pumpAndSettle();
    expect(result?.usePlatformDefault, isTrue);
    expect(result?.asset, isNull);
  });
}

final Uint8List _png = Uint8List.fromList(<int>[
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
