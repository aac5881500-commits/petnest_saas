import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_banner_display_settings.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_banner_carousel.dart';

void main() {
  test('舊資料沒有新欄位時維持經典模式', () {
    final ModernBannerFrameSetting old = ModernBannerFrameSetting.fromMap(
      <String, dynamic>{
        'homeBannerWidthPreset': 'full',
        'homeBannerHeightPreset': 'tall',
      },
    );
    expect(old.isActivity, isFalse);
    expect(old.showSectionTitle, isFalse);
    expect(old.displayMode, ModernBannerFrameSetting.modeClassic);
    expect(old.widthPreset, HomeBannerWidthPreset.full);
    expect(old.heightPreset, HomeBannerHeightPreset.tall);
    expect(old, isNot(const ModernBannerFrameSetting()));
    expect(
      ModernBannerFrameSetting.fromMap(<String, dynamic>{}),
      const ModernBannerFrameSetting(),
    );
  });

  test('活動模式往返儲存，切換模式不改寬高', () {
    const ModernBannerFrameSetting classic = ModernBannerFrameSetting(
      widthPreset: HomeBannerWidthPreset.narrow,
      heightPreset: HomeBannerHeightPreset.short,
    );
    final ModernBannerFrameSetting activity = classic.copyWith(
      displayMode: ModernBannerFrameSetting.modeActivity,
      showSectionTitle: true,
      sectionTitle: '最新優惠',
      sectionFontFamily: 'NotoSansTC',
      sectionTitleSize: ModernBannerFrameSetting.sizeLarge,
      sectionTitleWeight: ModernBannerFrameSetting.weightRegular,
      sectionTitleColorMode: ModernBannerFrameSetting.colorCustom,
      sectionTitleColor: 0xFF112233,
      sectionTitleAlign: ModernBannerFrameSetting.alignEnd,
      sectionTitleGap: ModernBannerFrameSetting.gapRelaxed,
      activityScroll: ModernBannerFrameSetting.scrollAuto,
      activitySeconds: 3,
      activityPeek: ModernBannerFrameSetting.peekStrong,
      activityGap: ModernBannerFrameSetting.gapCompact,
      activityRadius: ModernBannerFrameSetting.radiusLarge,
      showDots: false,
      dotColorMode: ModernBannerFrameSetting.colorCustom,
      dotColor: 0xFF445566,
    );
    final ModernBannerFrameSetting restored = ModernBannerFrameSetting.fromMap(
      activity.toMap(),
    );
    expect(restored, activity);
    expect(restored.widthPreset, HomeBannerWidthPreset.narrow);
    expect(restored.heightPreset, HomeBannerHeightPreset.short);
    final ModernBannerFrameSetting back = restored.copyWith(
      displayMode: ModernBannerFrameSetting.modeClassic,
    );
    expect(back.isActivity, isFalse);
    expect(back.sectionTitle, '最新優惠');
    expect(back.activitySeconds, 3);
  });

  test('無效秒數與模式回到安全預設', () {
    final ModernBannerFrameSetting frame =
        ModernBannerFrameSetting.fromMap(<String, dynamic>{
          'homeBannerDisplayMode': 'unknown',
          'homeBannerActivitySeconds': 99,
          'homeBannerActivityPeek': 'huge',
        });
    expect(frame.isActivity, isFalse);
    expect(frame.activitySeconds, 5);
    expect(frame.activityPeek, ModernBannerFrameSetting.peekStandard);
    expect(const ModernBannerFrameSetting().activityCardFraction, 0.85);
    expect(
      ModernBannerFrameSetting.fromMap(<String, dynamic>{
        'homeBannerActivityPeek': ModernBannerFrameSetting.peekSlight,
      }).activityCardFraction,
      0.90,
    );
    expect(
      ModernBannerFrameSetting.fromMap(<String, dynamic>{
        'homeBannerActivityPeek': ModernBannerFrameSetting.peekStrong,
      }).activityCardFraction,
      0.78,
    );
    expect(
      ModernBannerFrameSetting.fromMap(<String, dynamic>{
        'homeBannerActivityGap': 'compact',
      }).activityGapPx,
      8,
    );
  });

  testWidgets('經典模式仍使用整頁海報', (WidgetTester tester) async {
    await _pumpCarousel(
      tester,
      frame: const ModernBannerFrameSetting(),
      banners: _banners(2),
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(const Key('activity-banner-scroll')), findsNothing);
    expect(find.byKey(const Key('home-banner-section-title')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('活動模式露出下一張，最後一張不留空白', (WidgetTester tester) async {
    await _pumpCarousel(
      tester,
      width: 320,
      frame: const ModernBannerFrameSetting(
        displayMode: ModernBannerFrameSetting.modeActivity,
        activityPeek: ModernBannerFrameSetting.peekStandard,
      ),
      banners: _banners(3),
    );
    final Rect view = tester.getRect(
      find.byKey(const Key('activity-banner-scroll')),
    );
    final Rect first = tester.getRect(
      find.byKey(const Key('activity-banner-0')),
    );
    final Rect second = tester.getRect(
      find.byKey(const Key('activity-banner-1')),
    );
    expect(first.left, closeTo(view.left, 1));
    expect(first.width, closeTo(view.width * 0.85 - 12, 2));
    expect(second.left, lessThan(view.right));
    expect(second.right, greaterThan(view.right));
    expect(find.byKey(const Key('activity-banner-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('activity-banner-dot-2')), findsOneWidget);

    final double before = tester
        .getTopLeft(find.byKey(const Key('activity-banner-0')))
        .dx;
    await tester.drag(
      find.byKey(const Key('activity-banner-scroll')),
      const Offset(-140, 0),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('activity-banner-0'))).dx,
      lessThan(before - 8),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-banner-dot-2')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('activity-banner-dot-2'))).width,
      greaterThan(
        tester.getSize(find.byKey(const Key('activity-banner-dot-0'))).width,
      ),
    );
    expect(find.byKey(const Key('activity-banner-3')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('高度滑桿會改變海報高度', (WidgetTester tester) async {
    Future<double> heightOf(double factor) async {
      await _pumpCarousel(
        tester,
        width: 320,
        frame: ModernBannerFrameSetting(
          displayMode: ModernBannerFrameSetting.modeActivity,
          activityHeightFactor: factor,
        ),
        banners: _banners(2),
      );
      return tester.getSize(find.byKey(const Key('activity-banner-0'))).height;
    }

    final double short = await heightOf(0.45);
    final double tall = await heightOf(0.72);
    expect(tall, greaterThan(short + 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('一張海報不露出圓點，標題可開關', (WidgetTester tester) async {
    await _pumpCarousel(
      tester,
      frame: const ModernBannerFrameSetting(
        displayMode: ModernBannerFrameSetting.modeActivity,
        showSectionTitle: true,
        sectionTitle: '最新優惠',
      ),
      banners: _banners(1),
    );
    expect(find.byKey(const Key('activity-banner-dot-0')), findsNothing);
    expect(find.text('最新優惠'), findsOneWidget);
    final Rect card = tester.getRect(
      find.byKey(const Key('activity-banner-0')),
    );
    final Rect view = tester.getRect(
      find.byKey(const Key('activity-banner-scroll')),
    );
    expect(card.right, closeTo(view.right, 1));

    await _pumpCarousel(
      tester,
      frame: const ModernBannerFrameSetting(
        displayMode: ModernBannerFrameSetting.modeActivity,
      ),
      banners: _banners(1),
    );
    expect(find.byKey(const Key('home-banner-section-title')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('舊的自動輪播設定不會自動切換', (WidgetTester tester) async {
    String? tapped;
    await _pumpCarousel(
      tester,
      frame: const ModernBannerFrameSetting(
        displayMode: ModernBannerFrameSetting.modeActivity,
        activityScroll: ModernBannerFrameSetting.scrollAuto,
        activitySeconds: 3,
      ),
      banners: <StoreBannerModel>[
        const StoreBannerModel(
          id: 'one',
          actionType: StoreBannerActionTypes.product,
          actionTargetId: 'p1',
        ),
        const StoreBannerModel(id: 'two'),
      ],
      onTap: (StoreBannerModel banner) => tapped = banner.id,
    );
    await tester.tap(find.byKey(const Key('activity-banner-0')));
    await tester.pump();
    expect(tapped, 'one');
    await tester.pump(const Duration(seconds: 8));
    expect(
      tester.getSize(find.byKey(const Key('activity-banner-dot-0'))).width,
      greaterThan(
        tester.getSize(find.byKey(const Key('activity-banner-dot-1'))).width,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('手機與較寬預覽沒有溢出', (WidgetTester tester) async {
    for (final double width in <double>[320, 800]) {
      await _pumpCarousel(
        tester,
        width: width,
        frame: const ModernBannerFrameSetting(
          displayMode: ModernBannerFrameSetting.modeActivity,
          showSectionTitle: true,
          sectionTitle: '活動',
          activityRadius: ModernBannerFrameSetting.radiusLarge,
          activityGap: ModernBannerFrameSetting.gapRelaxed,
          activityWidth: 0.78,
          dotColorMode: ModernBannerFrameSetting.colorCustom,
          dotColor: 0xFF226644,
        ),
        banners: _banners(5),
      );
      final Rect view = tester.getRect(
        find.byKey(const Key('activity-banner-scroll')),
      );
      final Rect first = tester.getRect(
        find.byKey(const Key('activity-banner-0')),
      );
      expect(first.width, closeTo(view.width * 0.78 - 12, 2));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('設定切換模式不重建海報清單', (WidgetTester tester) async {
    ModernBannerFrameSetting current = const ModernBannerFrameSetting(
      widthPreset: HomeBannerWidthPreset.full,
    );
    final List<StoreBannerModel> banners = _banners(2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: HomeBannerDisplaySettings(
                    frame: current,
                    bannerCount: banners.length,
                    onChanged: (ModernBannerFrameSetting next) {
                      setState(() => current = next);
                    },
                    onManage: () {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('banner-mode-activity')));
    await tester.pumpAndSettle();
    expect(current.isActivity, isTrue);
    expect(current.widthPreset, HomeBannerWidthPreset.full);
    expect(banners.map((StoreBannerModel item) => item.id), <String>[
      'b0',
      'b1',
    ]);
    expect(find.text('活動滑動設定'), findsOneWidget);
    expect(find.text('自動輪播'), findsNothing);
    expect(find.text('海報寬度'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('banner-layout-narrow')));
    await tester.tap(find.byKey(const Key('banner-layout-narrow')));
    await tester.pumpAndSettle();
    expect(current.activityCardFraction, 0.72);
    expect(current.activityGapPx, 8);
    expect(current.activityInsetPx, 16);
    expect(current.matchedActivityLayout, 'narrow');
    expect(tester.takeException(), isNull);
  });
}

List<StoreBannerModel> _banners(int count) {
  return <StoreBannerModel>[
    for (int index = 0; index < count; index++) StoreBannerModel(id: 'b$index'),
  ];
}

Future<void> _pumpCarousel(
  WidgetTester tester, {
  required ModernBannerFrameSetting frame,
  required List<StoreBannerModel> banners,
  double width = 360,
  ValueChanged<StoreBannerModel>? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: ModernHomeBannerCarousel(
              banners: banners,
              theme: HomeThemeModel.modernDefault,
              frameSetting: frame,
              onBannerTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}
