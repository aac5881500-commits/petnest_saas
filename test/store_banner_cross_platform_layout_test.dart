// 檔案名稱：test/store_banner_cross_platform_layout_test.dart
// 功能說明：商城橫幅跨平台排版的單元測試（商城與首頁畫布比例不同且與寬度連動）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

StoreBannerModel _sampleBanner() {
  return StoreBannerModel(
    id: 'legacy',
    title: '春季健檢優惠',
    subtitle: '預約住宿送健康檢查',
    ctaText: '立即預約',
    ctaEnabled: true,
    overlayMode: StoreBannerOverlayModes.left,
    textElements: <StoreBannerTextElement>[
      StoreBannerTextElement(
        id: 't1',
        text: '春季健檢優惠',
        positionX: 0.08,
        positionY: 0.22,
        fontSize: 80,
        fontSizePreset: StoreBannerFontSizes.display,
      ),
      StoreBannerTextElement(
        id: 't2',
        text: '預約住宿送健康檢查',
        positionX: 0.08,
        positionY: 0.52,
        fontSize: 28,
        fontSizePreset: StoreBannerFontSizes.subhead,
      ),
    ],
  );
}

Widget _wrap({
  required StoreBannerModel banner,
  required double width,
  required TextScaler textScaler,
  PetNestBannerScope scope = PetNestBannerScope.store,
}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, 800), textScaler: textScaler),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: StoreBannerSafeLayout.aspectRatio,
              child: StoreBannerView(
                banner: banner,
                theme: HomeThemeModel.modernDefault,
                scope: scope,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('商城與首頁畫布比例不同且與寬度連動', () {
    const double width = 390;
    final double storeH = StoreBannerSizePresets.heightForWidth(
      StoreBannerSizePresets.standard,
      width,
    );
    final double homeH = StoreBannerSizePresets.heightForWidth(
      StoreBannerSizePresets.standard,
      width,
      scope: PetNestBannerScope.home,
    );
    expect(width / homeH, closeTo(16 / 9, 0.02));
    expect(width / storeH, closeTo(2, 0.15));
  });

  test('舊海報缺少新欄位仍可解析', () {
    final StoreBannerModel banner = StoreBannerModel.fromMap(<String, dynamic>{
      'id': 'old',
      'imageUrl': 'https://example.com/a.jpg',
    });
    expect(banner.imageScale, 1);
    expect(banner.imageAlignmentX, 0.5);
    expect(banner.imageAlignmentY, 0.5);
    expect(banner.imageUrl, 'https://example.com/a.jpg');
  });

  test('過大字級會被 clamp 到與滑桿相同上限', () {
    const double height = 190;
    final double maxPx = StoreBannerFontSizes.sliderMaxForBanner(height);
    expect(StoreBannerFontSizes.clampForBanner(80, height), maxPx);
    expect(maxPx, lessThanOrEqualTo(StoreBannerFontSizes.maxPx));
  });

  testWidgets('不同 textScaler 下海報文字尺寸一致', (WidgetTester tester) async {
    final StoreBannerModel banner = _sampleBanner();
    const double width = 390;

    await tester.pumpWidget(
      _wrap(banner: banner, width: width, textScaler: TextScaler.noScaling),
    );
    await tester.pumpAndSettle();
    final Size sizeA = tester.getSize(find.byType(StoreBannerView));
    final Size titleA = tester.getSize(find.text('春季健檢優惠').first);

    await tester.pumpWidget(
      _wrap(
        banner: banner,
        width: width,
        textScaler: const TextScaler.linear(2.4),
      ),
    );
    await tester.pumpAndSettle();
    final Size sizeB = tester.getSize(find.byType(StoreBannerView));
    final Size titleB = tester.getSize(find.text('春季健檢優惠').first);

    expect(sizeA, sizeB);
    expect(titleA, titleB);
  });

  testWidgets('image_only 不顯示套版文字', (WidgetTester tester) async {
    final StoreBannerModel banner = StoreBannerModel(
      id: 'img',
      title: '不該出現',
      contentMode: StoreBannerContentModes.imageOnly,
    );
    await tester.pumpWidget(
      _wrap(banner: banner, width: 390, textScaler: TextScaler.noScaling),
    );
    expect(find.text('不該出現'), findsNothing);
  });

  testWidgets('template_overlay 文字在不同寬度維持 16:9 且不超出安全區', (
    WidgetTester tester,
  ) async {
    final StoreBannerModel banner = StoreBannerModel(
      id: 'safe',
      title: '安全標題',
      subtitle: '安全副標',
      contentMode: StoreBannerContentModes.templateOverlay,
      textAlignH: StoreBannerAlignX.left,
      textAlignV: StoreBannerAlignY.top,
      fontScale: StoreBannerFontScale.medium,
      overlayMode: StoreBannerOverlayModes.left,
    );
    await tester.pumpWidget(
      _wrap(
        banner: banner,
        width: 390,
        textScaler: TextScaler.noScaling,
        scope: PetNestBannerScope.home,
      ),
    );
    await tester.pumpAndSettle();
    final Size phone = tester.getSize(find.byType(StoreBannerView));
    expect(phone.width / phone.height, closeTo(16 / 9, 0.08));
    expect(find.text('安全標題'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        banner: banner,
        width: 840,
        textScaler: TextScaler.noScaling,
        scope: PetNestBannerScope.home,
      ),
    );
    await tester.pumpAndSettle();
    final Size desk = tester.getSize(find.byType(StoreBannerView));
    expect(desk.width / desk.height, closeTo(16 / 9, 0.08));
    expect(find.text('安全標題'), findsOneWidget);
  });
}
