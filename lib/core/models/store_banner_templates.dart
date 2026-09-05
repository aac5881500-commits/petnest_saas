// 檔案名稱：lib/core/models/store_banner_templates.dart
// 功能說明：海報快速版型：只改漸層、文字與 CTA 排版，不覆蓋圖片與連結。

import 'package:petnest_saas/core/models/store_banner_model.dart';

class StoreBannerTemplates {
  static const String leftCopy = 'leftCopy';
  static const String rightCopy = 'rightCopy';
  static const String centerCopy = 'centerCopy';
  static const String imageOnly = 'imageOnly';
  static const String promo = 'promo';

  static const List<String> all = <String>[
    leftCopy,
    rightCopy,
    centerCopy,
    imageOnly,
    promo,
  ];

  static String label(String value) {
    switch (value) {
      case rightCopy:
        return '右文左圖';
      case centerCopy:
        return '中央文字';
      case imageOnly:
        return '純圖片';
      case promo:
        return '商城促銷';
      default:
        return '左文右圖';
    }
  }

  static StoreBannerModel apply(StoreBannerModel source, String template) {
    final String prefix = 'te_${source.id}';
    final String ctaText = source.ctaText.trim().isEmpty
        ? '開始選購'
        : source.ctaText;
    switch (template) {
      case rightCopy:
        return source.copyWith(
          overlayMode: StoreBannerOverlayModes.right,
          overlayColorMode: StoreBannerOverlayColors.dark,
          overlayExtent: StoreBannerOverlayExtents.large,
          overlayStrength: StoreBannerOverlayStrengths.strong,
          textAlign: StoreBannerTextAligns.right,
          textElements: <StoreBannerTextElement>[
            _line(
              id: '${prefix}_title',
              text: '精選商品組',
              x: 1.0,
              y: 0.16,
              size: StoreBannerFontSizes.title,
              weight: StoreBannerFontWeights.extraBold,
              color: StoreBannerCommonColors.white,
              align: StoreBannerTextAligns.right,
              width: StoreBannerTextWidthPresets.narrow,
              order: 0,
            ),
            _line(
              id: '${prefix}_sub',
              text: '現省優惠中',
              x: 1.0,
              y: 0.46,
              size: StoreBannerFontSizes.body,
              weight: StoreBannerFontWeights.medium,
              color: StoreBannerCommonColors.white,
              align: StoreBannerTextAligns.right,
              width: StoreBannerTextWidthPresets.narrow,
              order: 1,
            ),
          ],
          ctaEnabled: true,
          ctaText: ctaText,
          ctaShowArrow: true,
          ctaPositionX: 1.0,
          ctaPositionY: 0.82,
          ctaSize: StoreBannerCtaSizes.standard,
          ctaRadius: StoreBannerCtaRadii.pill,
        );
      case centerCopy:
        return source.copyWith(
          overlayMode: StoreBannerOverlayModes.bottom,
          overlayColorMode: StoreBannerOverlayColors.dark,
          overlayExtent: StoreBannerOverlayExtents.standard,
          overlayStrength: StoreBannerOverlayStrengths.strong,
          textAlign: StoreBannerTextAligns.center,
          textElements: <StoreBannerTextElement>[
            _line(
              id: '${prefix}_title',
              text: '安心選購毛孩用品',
              x: 0.5,
              y: 0.18,
              size: StoreBannerFontSizes.title,
              weight: StoreBannerFontWeights.extraBold,
              color: StoreBannerCommonColors.white,
              align: StoreBannerTextAligns.center,
              width: StoreBannerTextWidthPresets.wide,
              order: 0,
            ),
            _line(
              id: '${prefix}_sub',
              text: '本季精選，品質有保障',
              x: 0.5,
              y: 0.48,
              size: StoreBannerFontSizes.body,
              weight: StoreBannerFontWeights.medium,
              color: StoreBannerCommonColors.white,
              align: StoreBannerTextAligns.center,
              width: StoreBannerTextWidthPresets.standard,
              order: 1,
            ),
          ],
          ctaEnabled: true,
          ctaText: ctaText,
          ctaShowArrow: true,
          ctaPositionX: 0.5,
          ctaPositionY: 0.84,
          ctaSize: StoreBannerCtaSizes.standard,
          ctaRadius: StoreBannerCtaRadii.pill,
        );
      case imageOnly:
        return source.copyWith(
          overlayMode: StoreBannerOverlayModes.none,
          textAlign: StoreBannerTextAligns.left,
          textElements: const <StoreBannerTextElement>[],
          ctaEnabled: false,
          ctaShowArrow: false,
        );
      case promo:
        return source.copyWith(
          overlayMode: StoreBannerOverlayModes.bottom,
          overlayColorMode: StoreBannerOverlayColors.dark,
          overlayExtent: StoreBannerOverlayExtents.large,
          overlayStrength: StoreBannerOverlayStrengths.strong,
          textAlign: StoreBannerTextAligns.center,
          textElements: <StoreBannerTextElement>[
            _line(
              id: '${prefix}_tag',
              text: '組合優惠',
              x: 0.5,
              y: 0.08,
              size: StoreBannerFontSizes.small,
              weight: StoreBannerFontWeights.bold,
              color: StoreBannerCommonColors.orange,
              align: StoreBannerTextAligns.center,
              width: StoreBannerTextWidthPresets.narrow,
              order: 0,
            ),
            _line(
              id: '${prefix}_title',
              text: '保健三寶組',
              x: 0.5,
              y: 0.28,
              size: StoreBannerFontSizes.title,
              weight: StoreBannerFontWeights.extraBold,
              color: StoreBannerCommonColors.white,
              align: StoreBannerTextAligns.center,
              width: StoreBannerTextWidthPresets.standard,
              order: 1,
            ),
            _line(
              id: '${prefix}_sub',
              text: '限時優惠，數量有限',
              x: 0.5,
              y: 0.54,
              size: StoreBannerFontSizes.body,
              weight: StoreBannerFontWeights.medium,
              color: StoreBannerCommonColors.white,
              align: StoreBannerTextAligns.center,
              width: StoreBannerTextWidthPresets.standard,
              order: 2,
            ),
          ],
          ctaEnabled: true,
          ctaText: ctaText,
          ctaShowArrow: true,
          ctaPositionX: 0.5,
          ctaPositionY: 0.86,
          ctaSize: StoreBannerCtaSizes.standard,
          ctaRadius: StoreBannerCtaRadii.pill,
          ctaBackgroundColor: StoreBannerCommonColors.green,
          ctaTextColor: StoreBannerCommonColors.white,
        );
      default:
        return source.copyWith(
          overlayMode: StoreBannerOverlayModes.left,
          overlayColorMode: StoreBannerOverlayColors.dark,
          overlayExtent: StoreBannerOverlayExtents.large,
          overlayStrength: StoreBannerOverlayStrengths.strong,
          textAlign: StoreBannerTextAligns.left,
          textElements: <StoreBannerTextElement>[
            _line(
              id: '${prefix}_title',
              text: '寵物生活選品',
              x: 0.0,
              y: 0.16,
              size: StoreBannerFontSizes.title,
              weight: StoreBannerFontWeights.extraBold,
              color: StoreBannerCommonColors.white,
              align: StoreBannerTextAligns.left,
              width: StoreBannerTextWidthPresets.narrow,
              order: 0,
            ),
            _line(
              id: '${prefix}_sub',
              text: '精選推薦，安心帶回家',
              x: 0.0,
              y: 0.46,
              size: StoreBannerFontSizes.body,
              weight: StoreBannerFontWeights.medium,
              color: StoreBannerCommonColors.white,
              align: StoreBannerTextAligns.left,
              width: StoreBannerTextWidthPresets.narrow,
              order: 1,
            ),
          ],
          ctaEnabled: true,
          ctaText: ctaText,
          ctaShowArrow: true,
          ctaPositionX: 0.0,
          ctaPositionY: 0.82,
          ctaSize: StoreBannerCtaSizes.standard,
          ctaRadius: StoreBannerCtaRadii.pill,
        );
    }
  }

  static StoreBannerTextElement _line({
    required String id,
    required String text,
    required double x,
    required double y,
    required String size,
    required String weight,
    required int color,
    required String align,
    required String width,
    required int order,
  }) {
    return StoreBannerTextElement.create(
      id: id,
      text: text,
      positionX: x,
      positionY: y,
      fontSizePreset: size,
      fontSize: StoreBannerFontSizes.basePx(size),
      fontWeightPreset: weight,
      textColor: color,
      textAlign: align,
      maxWidthPreset: width,
      sortOrder: order,
    );
  }
}
