// 檔案名稱：test/platform_media_and_journal_appearance_test.dart
// 功能說明：平台圖庫資料解析與每日照護新舊外觀欄位相容、fallback。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_journal_appearance.dart';
import 'package:petnest_saas/core/models/daily_care_journal_layout.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/widgets/daily_care_card_surface.dart';
import 'package:petnest_saas/core/widgets/daily_care_illustrations.dart';
import 'package:petnest_saas/core/widgets/platform_media_library_scope.dart';

void main() {
  test('PlatformMediaAsset fromMap/toMap 與停用判斷', () {
    final PlatformMediaAsset asset =
        PlatformMediaAsset.fromMap('a1', <String, dynamic>{
          'name': '晨光',
          'category': PlatformMediaCategories.dailyCarePage,
          'imageUrl': 'https://example.com/a.jpg',
          'enabled': true,
          'sortOrder': 2,
          'fileBytes': 1200,
          'width': 1080,
          'height': 1920,
        });
    expect(asset.id, 'a1');
    expect(asset.enabled, isTrue);
    expect(asset.thumbnailUrl, 'https://example.com/a.jpg');
    expect(asset.toMap()['category'], PlatformMediaCategories.dailyCarePage);
    final PlatformMediaAsset disabled = PlatformMediaAsset.fromMap(
      'a2',
      <String, dynamic>{'enabled': false, 'imageUrl': 'https://x'},
    );
    expect(disabled.enabled, isFalse);
    expect(
      <PlatformMediaAsset>[asset, disabled]
          .where((PlatformMediaAsset item) => item.enabled)
          .map((PlatformMediaAsset item) => item.id),
      <String>['a1'],
    );
  });

  test('舊 backgroundType / cardBackgroundType 仍可讀', () {
    final DailyCareSettingModel parsed =
        DailyCareSettingModel.fromMap(<String, dynamic>{
          'backgroundType': DailyCareJournalTheme.typeImage,
          'backgroundImageUrl': 'https://old.example/page.png',
          'cardBackgroundType': DailyCareJournalTheme.cardTypeImage,
          'cardBackgroundImageUrl': 'https://old.example/card.png',
        });
    expect(parsed.backgroundImageUrl, 'https://old.example/page.png');
    expect(parsed.cardBackgroundImageUrl, 'https://old.example/card.png');
    expect(parsed.pageBackgroundSource, isEmpty);
    expect(parsed.hasCustomBackgroundImage, isTrue);
    expect(parsed.hasCustomCardBackgroundImage, isTrue);
  });

  test('新 asset ID 欄位 round trip', () {
    final DailyCareSettingModel setting = const DailyCareSettingModel()
        .copyWith(
          pageBackgroundSource: DailyCareJournalTheme.pageSourceLibrary,
          pageBackgroundAssetId: 'page-1',
          cardDefaultSurfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
          cardDefaultBackgroundAssetId: 'card-1',
          journalCards: DailyCareJournalCardLayout.mapFrom(<String, dynamic>{
            'food': <String, dynamic>{
              'surfaceMode': DailyCareJournalCardStyle.surfaceLibrary,
              'backgroundAssetId': 'food-1',
            },
            'relax': <String, dynamic>{
              'surfaceMode': DailyCareJournalCardStyle.surfaceTransparent,
            },
            'activity': <String, dynamic>{
              'surfaceMode': DailyCareJournalCardStyle.surfaceFrosted,
            },
            'photos': <String, dynamic>{
              'surfaceMode': DailyCareJournalCardStyle.surfaceSolid,
            },
          }),
        );
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      setting.toMap(),
    );
    expect(parsed.pageBackgroundAssetId, 'page-1');
    expect(parsed.cardDefaultBackgroundAssetId, 'card-1');
    expect(
      parsed
          .resolvedJournalCards[DailyCareJournalCardKeys.food]!
          .backgroundAssetId,
      'food-1',
    );
    expect(
      parsed.resolvedJournalCards[DailyCareJournalCardKeys.food]!.surfaceMode,
      DailyCareJournalCardStyle.surfaceLibrary,
    );
    expect(
      parsed.resolvedJournalCards[DailyCareJournalCardKeys.relax]!.surfaceMode,
      DailyCareJournalCardStyle.surfaceTransparent,
    );
    expect(
      parsed
          .resolvedJournalCards[DailyCareJournalCardKeys.activity]!
          .surfaceMode,
      DailyCareJournalCardStyle.surfaceFrosted,
    );
    expect(
      parsed.resolvedJournalCards[DailyCareJournalCardKeys.photos]!.surfaceMode,
      DailyCareJournalCardStyle.surfaceSolid,
    );
    expect(
      parsed
          .resolvedJournalCards[DailyCareJournalCardKeys.environment]!
          .surfaceMode,
      DailyCareJournalCardStyle.surfaceFollow,
    );
  });

  test('圖庫 asset 不存在或停用時 page/card fallback 不崩潰', () {
    const DailyCareSettingModel setting = DailyCareSettingModel(
      pageBackgroundSource: DailyCareJournalTheme.pageSourceLibrary,
      pageBackgroundAssetId: 'missing',
      cardDefaultSurfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
      cardDefaultBackgroundAssetId: 'missing-card',
    );
    final DailyCareResolvedPageLook page = DailyCareJournalAppearance.pageLook(
      setting,
      assetLookup: (_) => null,
    );
    expect(page.source, DailyCareJournalTheme.pageSourceSystem);
    expect(page.hasImage, isFalse);

    const DailyCareJournalCardLayout food = DailyCareJournalCardLayout(
      key: DailyCareJournalCardKeys.food,
      surfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
      backgroundAssetId: 'gone',
    );
    final DailyCareResolvedCardLook look = DailyCareJournalAppearance.cardLook(
      setting,
      food,
      fill: const Color(0xFFE8F1F8),
      assetLookup: (_) => null,
    );
    expect(look.mode, DailyCareJournalCardStyle.surfaceSolid);
    expect(look.hasImageVisual, isFalse);

    final PlatformMediaAsset disabled = PlatformMediaAsset.fromMap(
      'gone',
      <String, dynamic>{
        'enabled': false,
        'imageUrl': 'https://example.com/x.jpg',
      },
    );
    final DailyCareResolvedCardLook disabledLook =
        DailyCareJournalAppearance.cardLook(
          setting,
          food,
          fill: const Color(0xFFE8F1F8),
          assetLookup: (String id) => id == 'gone' ? disabled : null,
        );
    expect(disabledLook.mode, DailyCareJournalCardStyle.surfaceSolid);
  });

  testWidgets('renderer 表面在缺少圖庫時不崩潰', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyCareCardSurface(
            setting: DailyCareSettingModel(
              cardDefaultSurfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
              cardDefaultBackgroundAssetId: 'nope',
            ),
            layout: DailyCareJournalCardLayout(
              key: DailyCareJournalCardKeys.food,
              surfaceMode: DailyCareJournalCardStyle.surfaceTransparent,
            ),
            child: Text('ok'),
          ),
        ),
      ),
    );
    expect(find.text('ok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('霧化不會因平台標記預先改成透明，且會套用 BackdropFilter', () {
    const DailyCareResolvedCardLook frosted = DailyCareResolvedCardLook(
      mode: DailyCareJournalCardStyle.surfaceFrosted,
      fill: Color(0xFFFFFDFB),
    );
    const DailyCareResolvedCardLook transparent = DailyCareResolvedCardLook(
      mode: DailyCareJournalCardStyle.surfaceTransparent,
      fill: Color(0xFFFFFDFB),
    );
    expect(frosted.isFrosted, isTrue);
    expect(frosted.isTransparent, isFalse);
    expect(
      DailyCareJournalAppearance.shouldApplyFrostedBackdrop(frosted),
      isTrue,
    );
    expect(
      DailyCareJournalAppearance.shouldApplyFrostedBackdrop(transparent),
      isFalse,
    );
    expect(
      DailyCareJournalAppearance.cardWashOpacity(
        look: frosted,
        setting: const DailyCareSettingModel(),
      ),
      DailyCareJournalAppearance.frostedWash,
    );
    expect(
      DailyCareJournalAppearance.cardWashOpacity(
        look: transparent,
        setting: const DailyCareSettingModel(),
      ),
      DailyCareJournalAppearance.transparentWash,
    );
    expect(
      DailyCareJournalAppearance.frostedWash < 0.72,
      isTrue,
    );
  });

  testWidgets('frosted 卡片會建立 BackdropFilter，而不是只剩透明遮罩', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyCareCardSurface(
            setting: DailyCareSettingModel(
              cardDefaultSurfaceMode: DailyCareJournalCardStyle.surfaceFrosted,
            ),
            layout: DailyCareJournalCardLayout(
              key: DailyCareJournalCardKeys.food,
              surfaceMode: DailyCareJournalCardStyle.surfaceFrosted,
            ),
            child: Text('frost'),
          ),
        ),
      ),
    );
    expect(find.text('frost'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(find.byType(DailyCareFrostedGlass), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlatformMediaLibraryScope 可解析整頁與卡片圖庫 ID', (
    WidgetTester tester,
  ) async {
    final PlatformMediaAsset pageAsset = PlatformMediaAsset.fromMap(
      'page-1',
      <String, dynamic>{
        'name': '頁背景',
        'category': PlatformMediaCategories.dailyCarePage,
        'imageUrl': 'https://example.com/page.jpg',
        'enabled': true,
      },
    );
    final PlatformMediaAsset cardAsset = PlatformMediaAsset.fromMap(
      'card-1',
      <String, dynamic>{
        'name': '卡背景',
        'category': PlatformMediaCategories.dailyCareCard,
        'imageUrl': 'https://example.com/card.jpg',
        'enabled': true,
      },
    );
    final PlatformMediaAsset foodAsset = PlatformMediaAsset.fromMap(
      'food-1',
      <String, dynamic>{
        'name': '餐食卡',
        'category': PlatformMediaCategories.dailyCareCard,
        'imageUrl': 'https://example.com/food.jpg',
        'enabled': true,
      },
    );
    const DailyCareSettingModel setting = DailyCareSettingModel(
      pageBackgroundSource: DailyCareJournalTheme.pageSourceLibrary,
      pageBackgroundAssetId: 'page-1',
      cardDefaultSurfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
      cardDefaultBackgroundAssetId: 'card-1',
    );
    const DailyCareJournalCardLayout food = DailyCareJournalCardLayout(
      key: DailyCareJournalCardKeys.food,
      surfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
      backgroundAssetId: 'food-1',
    );

    late DailyCareResolvedPageLook pageLook;
    late DailyCareResolvedCardLook defaultLook;
    late DailyCareResolvedCardLook foodLook;
    late DailyCareResolvedCardLook missingLook;

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformMediaLibraryScope(
          assetsOverride: <String, PlatformMediaAsset>{
            pageAsset.id: pageAsset,
            cardAsset.id: cardAsset,
            foodAsset.id: foodAsset,
          },
          child: Builder(
            builder: (BuildContext context) {
              pageLook = DailyCareJournalAppearance.pageLook(
                setting,
                assetLookup: (String id) =>
                    PlatformMediaLibraryScope.lookup(context, id),
              );
              defaultLook = DailyCareJournalAppearance.defaultLook(
                setting,
                fill: const Color(0xFFFFFDFB),
                assetLookup: (String id) =>
                    PlatformMediaLibraryScope.lookup(context, id),
              );
              foodLook = DailyCareJournalAppearance.cardLook(
                setting,
                food,
                fill: const Color(0xFFFFFDFB),
                assetLookup: (String id) =>
                    PlatformMediaLibraryScope.lookup(context, id),
              );
              missingLook = DailyCareJournalAppearance.cardLook(
                setting,
                const DailyCareJournalCardLayout(
                  key: DailyCareJournalCardKeys.relax,
                  surfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
                  backgroundAssetId: 'missing',
                ),
                fill: const Color(0xFFFFFDFB),
                assetLookup: (String id) =>
                    PlatformMediaLibraryScope.lookup(context, id),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(pageLook.source, DailyCareJournalTheme.pageSourceLibrary);
    expect(pageLook.resolvedUrl, 'https://example.com/page.jpg');
    expect(defaultLook.mode, DailyCareJournalCardStyle.surfaceLibrary);
    expect(defaultLook.resolvedUrl, 'https://example.com/card.jpg');
    expect(foodLook.mode, DailyCareJournalCardStyle.surfaceLibrary);
    expect(foodLook.resolvedUrl, 'https://example.com/food.jpg');
    expect(missingLook.mode, DailyCareJournalCardStyle.surfaceSolid);
    expect(missingLook.hasImageVisual, isFalse);
  });

  test('圖庫原圖 overlay 不會蓋成白卡，文字區 veil 在 0.52～0.64', () {
    const DailyCareResolvedCardLook library = DailyCareResolvedCardLook(
      mode: DailyCareJournalCardStyle.surfaceLibrary,
      fill: Color(0xFFFFFDFB),
      asset: PlatformMediaAsset(
        id: 'c1',
        name: '卡',
        category: PlatformMediaCategories.dailyCareCard,
        imageUrl: 'https://example.com/c.jpg',
        thumbnailUrl: 'https://example.com/c.jpg',
        storagePath: 'platform/media_library/c1/original.jpg',
        width: 800,
        height: 600,
        fileBytes: 1000,
        sortOrder: 0,
        enabled: true,
      ),
    );
    const DailyCareSettingModel original = DailyCareSettingModel(
      cardBackgroundImageFade: DailyCareJournalTheme.fadeNone,
    );
    expect(
      DailyCareJournalAppearance.cardWashOpacity(
        look: library,
        setting: original,
      ),
      DailyCareJournalAppearance.libraryPhotoWashNone,
    );
    final double veil = DailyCareJournalAppearance.textReadabilityVeilOpacity(
      look: library,
      setting: original,
    );
    expect(veil, greaterThanOrEqualTo(0.52));
    expect(veil, lessThanOrEqualTo(0.64));
  });

  test('自訂深色、淺色、顏色不受 auto 對比修正影響', () {
    const ColorScheme colors = ColorScheme.light();
    const Color fill = Color(0xFFE8F1F8);
    const DailyCareJournalCardLayout dark = DailyCareJournalCardLayout(
      key: DailyCareJournalCardKeys.food,
      inkMode: DailyCareJournalCardStyle.inkDark,
    );
    const DailyCareJournalCardLayout light = DailyCareJournalCardLayout(
      key: DailyCareJournalCardKeys.food,
      inkMode: DailyCareJournalCardStyle.inkLight,
    );
    const DailyCareJournalCardLayout custom = DailyCareJournalCardLayout(
      key: DailyCareJournalCardKeys.food,
      inkMode: DailyCareJournalCardStyle.inkCustom,
      inkColorArgb: 0xFF112233,
    );
    const DailyCareJournalCardLayout auto = DailyCareJournalCardLayout(
      key: DailyCareJournalCardKeys.food,
      inkMode: DailyCareJournalCardStyle.inkAuto,
    );
    const DailyCareResolvedCardLook library = DailyCareResolvedCardLook(
      mode: DailyCareJournalCardStyle.surfaceLibrary,
      fill: fill,
    );
    expect(
      DailyCareInk.of(layout: dark, fill: fill, colors: colors, look: library),
      DailyCareInk.dark,
    );
    expect(
      DailyCareInk.of(layout: light, fill: fill, colors: colors, look: library),
      DailyCareInk.light,
    );
    expect(
      DailyCareInk.of(
        layout: custom,
        fill: fill,
        colors: colors,
        look: library,
      ),
      const Color(0xFF112233),
    );
    expect(
      DailyCareInk.of(layout: auto, fill: fill, colors: colors, look: library),
      DailyCareInk.dark,
    );
  });
}
