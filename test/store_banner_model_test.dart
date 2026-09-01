import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/models/store_banner_templates.dart';

void main() {
  test('舊 Banner 只有 imageUrl 仍可解析', () {
    final StoreBannerModel banner =
        StoreBannerModel.fromMap(const <String, dynamic>{
          'id': 'banner_1',
          'imageUrl': 'https://example.com/a.jpg',
          'imageStoragePath': 'shops/s1/store/banner_1/cover.jpg',
          'enabled': true,
          'sortOrder': 0,
          'actionType': 'product',
          'actionTargetId': 'p1',
        });
    expect(banner.hasImage, isTrue);
    expect(banner.sizePreset, StoreBannerSizePresets.standard);
    expect(banner.imageAlignmentX, 0.5);
    expect(banner.imageAlignmentY, 0.5);
    expect(banner.imageScale, 1);
    expect(banner.overlayMode, StoreBannerOverlayModes.none);
    expect(banner.blurMode, StoreBannerBlurModes.none);
    expect(banner.hasCopy, isFalse);
    expect(banner.actionType, StoreBannerActionTypes.product);
    expect(banner.textPositionX, 0.08);
    expect(banner.textPositionY, 0.42);
    expect(banner.textElements, isEmpty);
  });

  test('sizePreset 高度落在手機安全範圍', () {
    const double width = 390;
    expect(
      StoreBannerSizePresets.heightForWidth(
        StoreBannerSizePresets.small,
        width,
      ),
      inInclusiveRange(140, 155),
    );
    expect(
      StoreBannerSizePresets.heightForWidth(
        StoreBannerSizePresets.standard,
        width,
      ),
      inInclusiveRange(170, 190),
    );
    expect(
      StoreBannerSizePresets.heightForWidth(
        StoreBannerSizePresets.large,
        width,
      ),
      inInclusiveRange(210, 230),
    );
  });

  test('新漸層強度與範圍', () {
    expect(StoreBannerOverlayStrengths.opacity('light'), 0.35);
    expect(StoreBannerOverlayStrengths.opacity('standard'), 0.55);
    expect(StoreBannerOverlayStrengths.opacity('strong'), 0.75);
    expect(StoreBannerOverlayStrengths.opacity('extraStrong'), 0.95);
    expect(StoreBannerOverlayStrengths.opacity('deeper'), 1.0);
    expect(
      StoreBannerGradientSpec.alphas(StoreBannerOverlayStrengths.deeper)[0],
      greaterThan(
        StoreBannerGradientSpec.alphas(
          StoreBannerOverlayStrengths.extraStrong,
        )[0],
      ),
    );
    expect(
      StoreBannerGradientSpec.alphas(StoreBannerOverlayStrengths.deeper)[2],
      greaterThan(
        StoreBannerGradientSpec.alphas(
          StoreBannerOverlayStrengths.extraStrong,
        )[2],
      ),
    );
    expect(StoreBannerOverlayExtents.factor('small'), 0.45);
    expect(StoreBannerOverlayExtents.factor('standard'), 0.65);
    expect(StoreBannerOverlayExtents.factor('large'), 0.80);
    final List<double> stops = StoreBannerGradientSpec.stops(
      StoreBannerOverlayExtents.large,
    );
    expect(stops[0], 0);
    expect(stops[1], closeTo(0.248, 0.01));
    expect(stops[2], closeTo(0.448, 0.01));
    expect(stops[3], closeTo(0.648, 0.01));
    expect(stops[4], 0.80);
    expect(stops.last, 1);
    final List<double> alphas = StoreBannerGradientSpec.alphas(
      StoreBannerOverlayStrengths.extraStrong,
    );
    expect(alphas[0], closeTo(0.95, 0.001));
    expect(alphas[1], closeTo(0.80, 0.02));
    expect(alphas[2], closeTo(0.55, 0.02));
    expect(alphas[4], 0);
  });

  test('字幕位置與焦點會 clamp 到 0~1', () {
    final StoreBannerModel banner =
        StoreBannerModel.fromMap(const <String, dynamic>{
          'id': 'banner_2',
          'textPositionX': 4,
          'textPositionY': -1,
          'imageAlignmentX': 9,
          'imageAlignmentY': -3,
          'imageScale': 9,
        });
    expect(banner.textPositionX, 1);
    expect(banner.textPositionY, 0);
    expect(banner.imageAlignmentX, 1);
    expect(banner.imageAlignmentY, 0);
    expect(banner.imageScale, 2.5);
    final Map<String, dynamic> map = banner
        .copyWith(textPositionX: 0.92, textPositionY: 0.88)
        .toMap();
    expect(map['textPositionX'], 0.92);
    expect(map['textPositionY'], 0.88);
  });

  test('舊固定文案 runtime 轉成 TextElement', () {
    final StoreBannerModel banner =
        StoreBannerModel.fromMap(const <String, dynamic>{
          'id': 'legacy',
          'eyebrow': '組合優惠',
          'title': '保健三寶組',
          'subtitle': '安心選購',
          'promotionText': '現省 \$498',
          'ctaText': '開始選購',
          'textPositionX': 0.1,
          'textPositionY': 0.4,
        });
    expect(banner.textElements, isEmpty);
    final List<StoreBannerTextElement> items = banner.resolvedTextElements;
    expect(items.length, 4);
    expect(items.map((StoreBannerTextElement item) => item.text), <String>[
      '組合優惠',
      '保健三寶組',
      '安心選購',
      '現省 \$498',
    ]);
    expect(banner.showsCta, isTrue);
    expect(
      items.every((StoreBannerTextElement item) {
        return item.positionX >= 0 && item.positionX <= 1;
      }),
      isTrue,
    );
  });

  test('ctaEnabled false 重進編輯不會因殘留文案被打開', () {
    final StoreBannerModel banner = StoreBannerModel.fromMap(<String, dynamic>{
      'id': 'cta_off',
      'ctaEnabled': false,
      'ctaText': '開始選購',
      'textElements': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'te_1',
          'text': '主標題',
          'positionX': 0.1,
          'positionY': 0.2,
        },
      ],
    });
    expect(banner.ctaEnabled, isFalse);
    expect(banner.showsCta, isFalse);
    expect(banner.hydrateLegacyForEditor().ctaEnabled, isFalse);
  });

  test('舊資料沒有 ctaEnabled 時只在有按鈕文案才開啟', () {
    expect(
      StoreBannerModel.fromMap(const <String, dynamic>{
        'id': 'legacy_cta',
        'ctaText': '開始選購',
      }).ctaEnabled,
      isTrue,
    );
    expect(
      StoreBannerModel.fromMap(const <String, dynamic>{
        'id': 'blank',
      }).ctaEnabled,
      isFalse,
    );
  });

  test('新建海報預設純圖片空白', () {
    const StoreBannerModel banner = StoreBannerModel(id: 'blank_new');
    expect(banner.textElements, isEmpty);
    expect(banner.hasCopy, isFalse);
    expect(banner.ctaEnabled, isFalse);
    expect(banner.ctaText, isEmpty);
    expect(banner.actionType, StoreBannerActionTypes.none);
    expect(banner.overlayMode, StoreBannerOverlayModes.none);
    expect(banner.imageScale, 1);
    expect(banner.imageAlignmentX, 0.5);
    expect(banner.imageAlignmentY, 0.5);
  });

  test('新 textElements 優先於舊欄位', () {
    final StoreBannerModel banner = StoreBannerModel.fromMap(<String, dynamic>{
      'id': 'new',
      'title': '舊標題',
      'textElements': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'te_1',
          'text': '新文字',
          'positionX': 0.12,
          'positionY': 0.3,
          'fontSizePreset': 'display',
          'fontWeightPreset': 'extraBold',
          'textColor': 0xFF111111,
          'backgroundEnabled': true,
          'backgroundColor': 0xFFFF8A00,
          'backgroundStyle': 'capsule',
          'maxWidthPreset': 'narrow',
          'sortOrder': 0,
        },
      ],
    });
    expect(banner.resolvedTextElements.length, 1);
    expect(banner.resolvedTextElements.first.text, '新文字');
    expect(banner.resolvedTextElements.first.showsBackground, isTrue);
    expect(banner.toMap()['textElements'], isNotEmpty);
  });

  test('套用 Template 不覆蓋圖片', () {
    const StoreBannerModel source = StoreBannerModel(
      id: 'keep',
      imageUrl: 'https://example.com/cat.jpg',
      imageStoragePath: 'shops/s1/store/keep/cover.jpg',
      imageScale: 1.4,
      imageAlignmentX: 0.8,
    );
    final StoreBannerModel applied = StoreBannerTemplates.apply(
      source,
      StoreBannerTemplates.promo,
    );
    expect(applied.imageUrl, source.imageUrl);
    expect(applied.imageStoragePath, source.imageStoragePath);
    expect(applied.imageScale, 1.4);
    expect(applied.imageAlignmentX, 0.8);
    expect(applied.textElements.length, 3);
    expect(applied.overlayMode, StoreBannerOverlayModes.bottom);
    expect(applied.ctaEnabled, isTrue);
    expect(
      applied.textElements.every((StoreBannerTextElement item) {
        return !item.showsBackground;
      }),
      isTrue,
    );
    final StoreBannerModel imageOnly = StoreBannerTemplates.apply(
      source.copyWith(actionType: StoreBannerActionTypes.product),
      StoreBannerTemplates.imageOnly,
    );
    expect(imageOnly.ctaEnabled, isFalse);
    expect(imageOnly.textElements, isEmpty);
    expect(imageOnly.actionType, StoreBannerActionTypes.product);
  });

  test('5MB 錯誤文案', () {
    expect(StoreBannerModel.imageUserMessage('圖片大小不可超過 5MB'), '圖片不可超過 5 MB');
  });

  test('normalized position 會扣掉元件尺寸與安全距', () {
    const Size banner = Size(390, 190);
    const Size element = Size(120, 36);
    final Offset leftTop = StoreBannerPlacement.offsetOf(
      positionX: 0,
      positionY: 0,
      bannerSize: banner,
      elementSize: element,
    );
    expect(leftTop.dx, StoreBannerPlacement.padX);
    expect(leftTop.dy, StoreBannerPlacement.padY);
    final Offset rightBottom = StoreBannerPlacement.offsetOf(
      positionX: 1,
      positionY: 1,
      bannerSize: banner,
      elementSize: element,
    );
    expect(
      rightBottom.dx,
      banner.width - StoreBannerPlacement.padX - element.width,
    );
    expect(
      rightBottom.dy,
      banner.height - StoreBannerPlacement.padY - element.height,
    );
    final Offset mid = StoreBannerPlacement.offsetOf(
      positionX: 0.5,
      positionY: 0.5,
      bannerSize: banner,
      elementSize: element,
    );
    final Offset back = StoreBannerPlacement.normalize(
      actual: mid,
      bannerSize: banner,
      elementSize: element,
    );
    expect(back.dx, closeTo(0.5, 0.001));
    expect(back.dy, closeTo(0.5, 0.001));
    final Offset clamped = StoreBannerPlacement.clampActual(
      actual: const Offset(-40, 400),
      bannerSize: banner,
      elementSize: element,
    );
    expect(clamped.dx, StoreBannerPlacement.padX);
    expect(
      clamped.dy,
      lessThanOrEqualTo(banner.height - StoreBannerPlacement.padY),
    );
  });

  test('舊 positionPreset 可轉成 normalized position', () {
    final StoreBannerTextElement element = StoreBannerTextElement.fromMap(
      const <String, dynamic>{
        'id': 'legacy_pos',
        'text': '舊位置',
        'positionPreset': 'leftBottom',
      },
    );
    expect(element.positionX, 0.08);
    expect(element.positionY, 0.88);
  });

  test('舊首頁 Banner 只有 imageUrl 與 isActive 仍可解析', () {
    final StoreBannerModel banner =
        StoreBannerModel.fromMap(const <String, dynamic>{
          'imageUrl': 'https://example.com/home.jpg',
          'imageStoragePath': 'shops/s1/banner_1.jpg',
          'isActive': true,
        });
    expect(banner.hasImage, isTrue);
    expect(banner.enabled, isTrue);
    expect(banner.hasCopy, isFalse);
    expect(banner.usesOwnOverlay, isFalse);
    expect(banner.overlayMode, StoreBannerOverlayModes.none);
    expect(banner.actionType, StoreBannerActionTypes.none);
    expect(banner.toMap()['isActive'], isTrue);
  });

  test('舊首頁 isActive false 會關閉', () {
    final StoreBannerModel banner = StoreBannerModel.fromMap(
      const <String, dynamic>{'isActive': false, 'imageUrl': 'https://x'},
    );
    expect(banner.enabled, isFalse);
  });

  test('首頁 actionType 不會被洗成 none', () {
    expect(
      StoreBannerModel.fromMap(const <String, dynamic>{
        'actionType': 'booking',
      }).actionType,
      HomeBannerActionTypes.booking,
    );
    expect(
      StoreBannerModel.fromMap(const <String, dynamic>{
        'actionType': 'store',
      }).actionType,
      HomeBannerActionTypes.store,
    );
    expect(
      StoreBannerModel.fromMap(const <String, dynamic>{
        'actionType': 'url',
      }).actionType,
      HomeBannerActionTypes.url,
    );
    expect(
      StoreBannerModel.fromMap(const <String, dynamic>{
        'actionType': 'externalUrl',
      }).actionType,
      HomeBannerActionTypes.url,
    );
    expect(
      StoreBannerModel.fromMap(const <String, dynamic>{
        'actionType': 'url',
        'actionTargetId': 'https://example.com',
      }).actionTargetId,
      'https://example.com',
    );
  });

  test('首頁標準尺寸接近 16:9 且手機不過高', () {
    const double width = 390;
    expect(
      StoreBannerSizePresets.heightForWidth(
        StoreBannerSizePresets.standard,
        width,
        scope: PetNestBannerScope.home,
      ),
      inInclusiveRange(180, 210),
    );
    expect(
      StoreBannerSizePresets.heightForWidth(
        StoreBannerSizePresets.large,
        width,
        scope: PetNestBannerScope.home,
      ),
      inInclusiveRange(210, 230),
    );
  });
}
