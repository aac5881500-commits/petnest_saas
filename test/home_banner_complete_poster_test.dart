// 檔案名稱：test/home_banner_complete_poster_test.dart
// 功能說明：首頁海報保留製作工具，發布後前台只顯示固定成品圖。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/store_banner_render_service.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

void main() {
  test('後台工具與手機桌機排版仍在同一套編輯器', () {
    final String editor = File(
      'lib/features/shop/pages/store/shop_store_banner_editor_page.dart',
    ).readAsStringSync();
    final String media = File(
      'lib/features/shop/pages/shop_media_page.dart',
    ).readAsStringSync();
    final String preview = File(
      'lib/features/shop/widgets/modern_home/modern_home_editor_preview.dart',
    ).readAsStringSync();
    for (final String label in <String>['圖片', '漸層', '文字', '按鈕', '連結']) {
      expect(editor.contains("Tab(text: '$label')"), isTrue, reason: label);
    }
    expect(editor.contains('快速版型'), isTrue);
    expect(editor.contains('圖片縮放'), isTrue);
    expect(editor.contains('fixedHomeCanvas: widget.isHomeScope'), isTrue);
    expect(media.contains('HomeBannerEditorPanel'), isFalse);
    expect(media.contains('ShopStoreBannerEditorPage'), isTrue);
    expect(media.contains('預覽海報'), isTrue);
    expect(media.contains('發布海報'), isTrue);
    expect(media.contains('return _bannerList(dense: false)'), isTrue);
    expect(media.contains('ModernHomeEditorPreview'), isTrue);
    expect(media.contains('showPhoneChrome: false'), isTrue);
    expect(media.contains('draftHomeBanners:'), isTrue);
    expect(media.contains('ShopBannerDevicePreview'), isFalse);
    expect(preview.contains('ShopPublicModernPage'), isTrue);
    expect(preview.contains('draftHomeBanners'), isTrue);
  });

  test('發布畫布固定 1600 × 900', () {
    expect(StoreBannerRenderService.targetWidth, 1600);
    expect(StoreBannerRenderService.targetHeight, 900);
    final img.Image fitted = StoreBannerRenderService.fitHomeCanvas(
      img.Image(width: 10, height: 10),
    );
    expect(fitted.width, 1600);
    expect(fitted.height, 900);
    final img.Image kept = StoreBannerRenderService.fitHomeCanvas(
      img.Image(width: 1600, height: 900),
    );
    expect(kept.width, 1600);
    expect(kept.height, 900);
  });

  test('顧客前台優先成品圖，草稿欄位仍保留', () {
    final StoreBannerModel published = StoreBannerModel(
      id: 'baked',
      imageUrl: 'https://example.com/raw.jpg',
      renderedImageUrl: 'https://example.com/final.jpg',
      title: '草稿標題',
      ctaText: '立即預約',
      ctaEnabled: true,
      overlayMode: StoreBannerOverlayModes.left,
    );
    expect(published.hasPublishedPoster, isTrue);
    expect(published.frontImageUrl, 'https://example.com/final.jpg');
    expect(published.title, '草稿標題');

    final StoreBannerModel legacy = StoreBannerModel.fromMap(
      const <String, dynamic>{
        'id': 'old',
        'imageUrl': 'https://example.com/raw.jpg',
        'title': '舊標題',
      },
    );
    expect(legacy.hasPublishedPoster, isFalse);
    expect(legacy.frontImageUrl, 'https://example.com/raw.jpg');
    expect(legacy.title, '舊標題');
  });

  test('新舊海報混合仍固定 16:9，尺寸只改外距', () {
    final StoreBannerModel published = StoreBannerModel(
      id: 'new',
      renderedImageUrl: 'https://example.com/final.jpg',
      sizePreset: StoreBannerSizePresets.large,
    );
    final StoreBannerModel legacy = StoreBannerModel(
      id: 'old',
      imageUrl: 'https://example.com/raw.jpg',
      sizePreset: StoreBannerSizePresets.small,
    );
    expect(
      HomeBannerDisplay.frameAspect(
        banners: <StoreBannerModel>[published, legacy],
        legacyAspect: 2.4,
      ),
      HomeBannerDisplay.aspectRatio,
    );
    expect(
      HomeBannerDisplay.outerPadding(HomeBannerDisplaySize.small).left,
      16,
    );
  });

  test('未儲存暫存圖離開才刪，已發布圖要等儲存成功', () {
    final HomeBannerImageCleanup cleanup = HomeBannerImageCleanup();
    final List<HomeBannerStoredImage> replaced = cleanup.replacePending(
      const HomeBannerStoredImage(url: 'new', path: 'new/path'),
    );
    expect(replaced, isEmpty);
    cleanup.retireSaved(const HomeBannerStoredImage(url: 'old-a', path: 'a'));
    cleanup.retireSaved(const HomeBannerStoredImage(url: 'old-b', path: 'b'));
    final List<HomeBannerStoredImage> dropped = cleanup.abandon();
    expect(dropped.map((HomeBannerStoredImage image) => image.url), ['new']);
    expect(cleanup.retireAfterSave, isEmpty);

    final HomeBannerImageCleanup saved = HomeBannerImageCleanup();
    saved.replacePending(const HomeBannerStoredImage(url: 'keep', path: 'k'));
    saved.retireSaved(const HomeBannerStoredImage(url: 'old-a', path: 'a'));
    saved.retireSaved(const HomeBannerStoredImage(url: 'old-b', path: 'b'));
    final List<HomeBannerStoredImage> retired = saved.commitSave();
    expect(retired.map((HomeBannerStoredImage image) => image.url), <String>[
      'old-a',
      'old-b',
    ]);
    expect(saved.pending, isEmpty);
  });

  testWidgets('已發布成品不畫動態文字、按鈕、漸層', (WidgetTester tester) async {
    final StoreBannerModel banner = StoreBannerModel(
      id: 'poster',
      imageUrl: 'https://example.com/raw.jpg',
      renderedImageUrl: 'https://example.com/final.jpg',
      sizePreset: StoreBannerSizePresets.large,
      title: '不該出現',
      ctaText: '按鈕',
      ctaEnabled: true,
      overlayMode: StoreBannerOverlayModes.left,
      actionType: HomeBannerActionTypes.rooms,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: StoreBannerView(
                banner: banner,
                theme: HomeThemeModel.modernDefault,
                scope: PetNestBannerScope.home,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final Size size = tester.getSize(find.byType(StoreBannerView));
    expect(size.width / size.height, closeTo(16 / 9, 0.02));
    expect(find.text('不該出現'), findsNothing);
    expect(find.text('按鈕'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient != null,
      ),
      findsNothing,
    );
  });

  testWidgets('編輯預覽仍可即時看到草稿文字', (WidgetTester tester) async {
    final StoreBannerModel banner = StoreBannerModel(
      id: 'draft',
      imageUrl: 'https://example.com/raw.jpg',
      renderedImageUrl: 'https://example.com/final.jpg',
      title: '草稿標題',
      contentMode: '',
      textElements: <StoreBannerTextElement>[
        StoreBannerTextElement(
          id: 't1',
          text: '草稿標題',
          positionX: 0.1,
          positionY: 0.2,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 203,
            child: StoreBannerView(
              banner: banner,
              theme: HomeThemeModel.modernDefault,
              scope: PetNestBannerScope.home,
              composeLive: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('草稿標題'), findsWidgets);
  });
}
