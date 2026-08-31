import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

void main() {
  testWidgets('392px 有字幕不 overflow，無字幕不渲染文字', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const StoreBannerModel withCopy = StoreBannerModel(
      id: 'b1',
      title: '保健三寶組保健三寶組保健三寶組',
      subtitle: '營養補充一次備齊營養補充一次備齊',
      ctaText: '開始選購',
      ctaEnabled: true,
      overlayMode: StoreBannerOverlayModes.left,
      overlayExtent: StoreBannerOverlayExtents.large,
      overlayStrength: StoreBannerOverlayStrengths.extraStrong,
      overlayColorMode: StoreBannerOverlayColors.warmCream,
    );
    const StoreBannerModel imageOnly = StoreBannerModel(id: 'b2');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 392,
            child: StoreBannerView(
              banner: withCopy,
              theme: HomeThemeModel.modernDefault,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('開始選購'), findsOneWidget);
    expect(find.textContaining('保健三寶組'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 392,
            child: StoreBannerView(
              banner: imageOnly,
              theme: HomeThemeModel.modernDefault,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('開始選購'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自由文字與膠囊背景可渲染', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final StoreBannerModel banner = StoreBannerModel(
      id: 'b3',
      overlayMode: StoreBannerOverlayModes.left,
      overlayColorMode: StoreBannerOverlayColors.warmCream,
      overlayExtent: StoreBannerOverlayExtents.large,
      overlayStrength: StoreBannerOverlayStrengths.extraStrong,
      ctaEnabled: true,
      ctaText: '開始選購',
      ctaShowArrow: true,
      textElements: <StoreBannerTextElement>[
        StoreBannerTextElement.create(
          id: 't1',
          text: '組合優惠',
          positionX: 0.08,
          positionY: 0.14,
          fontSizePreset: StoreBannerFontSizes.subhead,
          textColor: StoreBannerCommonColors.green,
        ),
        StoreBannerTextElement.create(
          id: 't2',
          text: '保健三寶組',
          positionX: 0.08,
          positionY: 0.34,
          fontSizePreset: StoreBannerFontSizes.display,
          fontWeightPreset: StoreBannerFontWeights.extraBold,
        ),
        StoreBannerTextElement.create(
          id: 't3',
          text: '現省 \$498',
          positionX: 0.08,
          positionY: 0.58,
          fontSizePreset: StoreBannerFontSizes.title,
          backgroundEnabled: true,
          backgroundColor: StoreBannerCommonColors.orange,
          backgroundStyle: StoreBannerTextBgStyles.capsule,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 392,
            child: StoreBannerView(
              banner: banner,
              theme: HomeThemeModel.modernDefault,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('組合優惠'), findsOneWidget);
    expect(find.text('保健三寶組'), findsOneWidget);
    expect(find.text(r'現省 $498'), findsOneWidget);
    expect(find.text('開始選購 →'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖曳文字會寫回 normalized position', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    StoreBannerModel banner = StoreBannerModel(
      id: 'drag',
      textElements: <StoreBannerTextElement>[
        StoreBannerTextElement.create(
          id: 't1',
          text: '新文字',
          positionX: 0.08,
          positionY: 0.22,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 392,
            child: StoreBannerView(
              banner: banner,
              theme: HomeThemeModel.modernDefault,
              interactMode: StoreBannerInteractMode.text,
              onChanged: (StoreBannerModel next) {
                banner = next;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.text('新文字'), const Offset(80, 30));
    await tester.pumpAndSettle();
    expect(banner.resolvedTextElements.first.positionX, greaterThan(0.08));
    expect(banner.resolvedTextElements.first.positionX, lessThanOrEqualTo(1));
    expect(banner.resolvedTextElements.first.positionY, greaterThan(0.22));
    expect(banner.resolvedTextElements.first.positionY, lessThanOrEqualTo(1));
  });
}
