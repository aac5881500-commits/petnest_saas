import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_review_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/review_section_settings_panel.dart';

ReviewModel review(int i, {String status = 'visible'}) => ReviewModel(
  reviewId: '$i',
  shopId: 's',
  bookingId: 'b',
  userId: 'u',
  customerName: '顧客$i',
  petNames: const [],
  roomTypeName: '',
  startDate: null,
  endDate: null,
  nights: 1,
  rating: i == 1 ? 4 : 5,
  environmentRating: 5,
  serviceRating: 5,
  priceRating: 4,
  content: List.filled(12, '照顧細心，每天都有照片，希望接送時間更彈性。').join(),
  imageUrls: const [],
  reply: '謝謝分享，我們會持續改善接送服務。',
  replyAt: null,
  replyBy: '',
  status: status,
  createdAt: null,
  updatedAt: null,
);

void main() {
  test(
    'six layouts persist, remain independent, and miniature safely falls back',
    () {
      expect(HomeReviewLayouts.all.length, 6);
      for (final layout in HomeReviewLayouts.all) {
        final setting = HomeReviewSectionSetting.fromMap(
          HomeReviewSectionSetting(
            layout: layout,
            miniPlacement: 'bannerBottomRight',
            contentLines: 12,
            textSize: 18,
          ).toMap(),
        );
        expect(setting.layout, layout);
        expect(setting.isHalf, false);
        expect(setting.contentLines, 12);
        expect(setting.textSize, 18);
        expect(setting.miniPlacement, 'bannerBottomRight');
      }
      const mini = HomeReviewSectionSetting(layout: HomeReviewLayouts.mini);
      expect(mini.overlaysBanner(true), true);
      expect(mini.overlaysBanner(false), false);
      expect(
        mini.copyWith(miniPlacement: 'inline').overlaysBanner(true),
        false,
      );
      final invalid = HomeReviewSectionSetting.fromMap({
        'miniPlacement': 'bad',
        'contentLines': 900,
        'textSize': -1,
      });
      expect(invalid.miniPlacement, 'bannerTopRight');
      expect(invalid.contentLines, 12);
      expect(invalid.textSize, 12);
    },
  );

  for (final layout in HomeReviewLayouts.all) {
    testWidgets(
      '$layout handles narrow screens, long reviews, and opens all reviews',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ModernReviewSection(
                    theme: HomeThemeModel.modernDefault,
                    setting: HomeReviewSectionSetting(
                      layout: layout,
                      carouselCount: 5,
                      textSize: 18,
                      contentLines: 12,
                    ),
                    reviews: [
                      for (var i = 0; i < 5; i++) review(i),
                      review(99, status: 'hidden'),
                    ],
                    phase: HomeInfoSectionPhase.ready,
                    onOpen: () {
                      opened++;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('顧客99'), findsNothing);
        final entry = find.byKey(
          Key(
            layout == HomeReviewLayouts.mini
                ? 'home-review-mini'
                : 'home-review-see-all',
          ),
        );
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty, loading, and failed states retain honest public entry', (
    tester,
  ) async {
    for (final phase in [
      HomeInfoSectionPhase.ready,
      HomeInfoSectionPhase.loading,
      HomeInfoSectionPhase.unavailable,
    ]) {
      for (final layout in [
        HomeReviewLayouts.scoreCompact,
        HomeReviewLayouts.mini,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernReviewSection(
                theme: HomeThemeModel.modernDefault,
                setting: HomeReviewSectionSetting(layout: layout),
                reviews: const [],
                phase: phase,
                onOpen: () {},
              ),
            ),
          ),
        );
        expect(find.textContaining('4.8'), findsNothing);
        expect(find.byType(InkWell), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'owner settings offer six designs and miniature placement with banner warning',
    (tester) async {
      HomeInformationSectionsSetting? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewSectionSettingsPanel(
              theme: HomeThemeModel.modernDefault,
              setting: const HomeInformationSectionsSetting(
                reviews: HomeReviewSectionSetting(
                  layout: HomeReviewLayouts.mini,
                ),
              ),
              onChanged: (value) {
                draft = value;
              },
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('info-layout-mini')), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('目前沒有啟用的海報'), 200);
      expect(find.textContaining('目前沒有啟用的海報'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 900));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('info-layout-featured')));
      expect(draft!.reviews.layout, HomeReviewLayouts.featured);
      expect(draft!.reviews.showImages, true);
      expect(draft!.reviews.showOnHome, true);
      expect(draft!.reviews.showViewAll, true);
    },
  );
}
