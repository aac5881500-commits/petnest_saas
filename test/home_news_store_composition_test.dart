import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_news_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_store_action.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/editorial_section_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_store_card.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_entrance_banner.dart';

final items = List.generate(
  5,
  (i) => HomeNewsItem(
    id: 'n$i',
    sourceType: HomeNewsSources.notices,
    title: '住宿前的小提醒 $i',
    summary: '熟悉環境，安心安排住宿。',
    publishedAt: DateTime(2026, 11, i + 1),
    pinned: false,
    iconType: 'normal',
  ),
);
const theme = HomeThemeModel.modernDefault;
void main() {
  test(
    'new layout choices and heading controls round-trip without deleting photos',
    () {
      final news = const HomeNewsSectionSetting(
        layout: HomeNewsLayouts.imageCarousel,
        showHeading: true,
        headingAccent: false,
        photoUrl: 'https://example.com/custom.jpg',
        secondPhotoUrl: 'builtin-env:warm-about',
      );
      final n = HomeNewsSectionSetting.fromMap(news.toMap());
      expect(n.layout, HomeNewsLayouts.imageCarousel);
      expect(n.showHeading, true);
      expect(n.headingAccent, false);
      expect(n.photoUrl, news.photoUrl);
      expect(n.secondPhotoUrl, news.secondPhotoUrl);
      final store = const ModernStoreHomeSetting(
        storeEntryPlacement: 'news',
        storeSectionTitle: '好物商城',
        storeHeadingAccent: false,
        storeBannerImageUrl: 'builtin-store:goods',
      );
      final s = ModernStoreHomeSetting.fromMap(store.toMap());
      expect(s.storeEntryPlacement, 'news');
      expect(s.storeSectionTitle, '好物商城');
      expect(s.storeHeadingAccent, false);
      expect(s.storeBannerImageUrl, store.storeBannerImageUrl);
      expect(
        ModernStoreHomeSetting.fromMap({
          'storeEntryPlacement': 'bad',
        }).storeEntryPlacement,
        'standalone',
      );
      expect(
        HomeRoomSectionSetting.fromMap(
          const HomeRoomSectionSetting(headingAccent: false).toMap(),
        ).headingAccent,
        false,
      );
    },
  );
  for (final width in [320.0, 390.0, 900.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'news image layouts and combined mall at width $width scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1300);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final layout in [
            HomeNewsLayouts.feature,
            HomeNewsLayouts.imageCarousel,
          ]) {
            var newsOpened = false, storeOpened = false;
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1300),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: ModernHomeNewsSection(
                        theme: theme,
                        setting: HomeNewsSectionSetting(
                          layout: layout,
                          showHeading: true,
                          title: '店裡的新鮮事',
                          showDate: true,
                          multiLineCount: 5,
                        ),
                        items: items,
                        phase: HomeNewsSectionPhase.ready,
                        preview: false,
                        onOpen: (_) => newsOpened = true,
                        storeAside: layout == HomeNewsLayouts.feature
                            ? HomeStoreAction(
                                setting: const ModernStoreHomeSetting(
                                  storeBannerTitle: '好物商城',
                                  storeBannerButtonText: '逛逛商城',
                                  storeBannerImageUrl: 'builtin-store:goods',
                                ),
                                theme: theme,
                                onTap: () => storeOpened = true,
                                photoCard: true,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: layout);
            expect(find.text('店裡的新鮮事'), findsOneWidget);
            await tester.tap(find.byKey(const ValueKey('news-image-n0')));
            expect(newsOpened, true);
            if (layout == HomeNewsLayouts.feature) {
              await tester.tap(find.text('逛逛商城'));
              expect(storeOpened, true);
            } else {
              await tester.tap(find.byTooltip('第2頁消息'));
              await tester.pumpAndSettle();
              expect(find.text('住宿前的小提醒 2'), findsOneWidget);
            }
            expect(tester.takeException(), isNull, reason: layout);
          }
        },
      );
    }
  }
  testWidgets('store heading is editable separately from card title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ModernHomeStoreCard(
            theme: theme,
            setting: ModernStoreHomeSetting(
              storeSectionTitle: '好物推薦',
              storeBannerTitle: '店家商城',
              storeEntryLayout: ModernStoreEntryLayouts.ticket,
            ),
          ),
        ),
      ),
    );
    expect(find.text('好物推薦'), findsOneWidget);
    expect(find.text('店家商城'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('closed mall preserves news and does not create mall links', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoreEntranceBanner(
          shopId: 'x',
          shop: const {},
          theme: theme,
          setting: const ModernStoreHomeSetting(),
          whenClosed: const Text('原消息'),
          builder: (_) => const Text('商城按鈕'),
        ),
      ),
    );
    expect(find.text('原消息'), findsOneWidget);
    expect(find.text('商城按鈕'), findsNothing);
  });
  testWidgets('room header mall action keeps all-rooms link below', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorialRoomStrip(
            rooms: const [],
            theme: theme,
            title: '房型介紹',
            onRoom: (_) {},
            onAll: () {},
            headerTrailing: const Text('逛商城'),
          ),
        ),
      ),
    );
    expect(find.text('逛商城'), findsOneWidget);
    expect(find.text('查看全部房型 ›'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
