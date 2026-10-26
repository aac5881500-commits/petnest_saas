import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
import 'package:petnest_saas/core/services/shop_intro_guide_progress.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/features/shop/widgets/shop_opening_progress.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_about_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_environment_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_faq_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_news_section.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('儲存欄位、照片格式、外觀與草稿發布區分', () {
    expect(ShopIntroContent.environment({}), isFalse);
    expect(
      ShopIntroContent.environment({
        'environmentIntro': {
          'environmentPresentation': {'preset': 'warm'},
        },
      }),
      isFalse,
    );
    expect(
      ShopIntroContent.environment({
        'environmentIntro': {
          'galleryImages': [
            {'imageUrl': 'https://local/actual.jpg'},
          ],
        },
      }),
      isTrue,
    );
    expect(
      ShopIntroContent.environment({
        'environmentIntro': {
          'galleryImages': ['https://local/legacy.jpg'],
        },
      }),
      isTrue,
    );
    expect(
      ShopIntroContent.environment({
        'environmentIntro': {'heroSubtitle': '安心・舒適・乾淨的貓咪住宿空間'},
      }),
      isTrue,
    );
    expect(
      ShopIntroContent.environment({
        'environmentIntro': {
          'facilityKeys': ['water'],
        },
      }),
      isTrue,
    );
    expect(
      ShopIntroContent.about({'aboutTitle': '關於我們', 'aboutDescription': '  '}),
      isFalse,
    );
    expect(ShopIntroContent.about({'aboutDescription': '本店照護理念'}), isTrue);
    expect(
      ShopIntroContent.about({
        'homeAppearance': {
          'aboutPage': {'layout': 'team'},
        },
      }),
      isFalse,
    );
    expect(
      ShopIntroContent.entries([
        {'question': 'Q', 'answer': ' ', 'isPublished': true},
      ], faq: true),
      ShopIntroContentStatus.empty,
    );
    expect(
      ShopIntroContent.entries([
        {'title': '公告', 'content': '內容', 'isPublished': false},
      ], faq: false),
      ShopIntroContentStatus.unpublished,
    );
  });
  test('逐項保存、略過隔離、重登入與舊收合偏好遷移', () async {
    await ShopIntroGuideProgress.save('s', completed: {'environment'});
    await ShopIntroGuideProgress.save('s', skipped: {'announcement'});
    var progress = await ShopIntroGuideProgress.load('s', 'another-owner');
    expect(progress.handled('environment'), isTrue);
    expect(progress.skipped, {'announcement'});
    expect(progress.ended, isFalse);
    expect(
      (await ShopIntroGuideProgress.load('other', 'u')).handled('environment'),
      isFalse,
    );
    await ShopIntroGuideProgress.save(
      's',
      completed: {'about'},
      skipped: {'faq'},
    );
    progress = await ShopIntroGuideProgress.load('s', 'u');
    expect(progress.ended, isTrue);
    await ShopIntroGuideProgress.save('s');
    expect((await ShopIntroGuideProgress.load('s', 'u')).ended, isTrue);
    SharedPreferences.setMockInitialValues({
      'openingOptional:old:legacy': true,
    });
    final old = await ShopIntroGuideProgress.load('legacy', 'old');
    expect(old.ended, isTrue);
    expect(old.completed, isEmpty);
    expect(
      (await ShopIntroGuideProgress.load('legacy', 'new-login')).ended,
      isTrue,
    );
  });

  testWidgets('儲存返回逐卡移除、取消不減少、各自略過與結束後刪除不重現', (tester) async {
    for (final width in [320.0, 390.0, 1280.0]) {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(Size(width, 1000));
      final nav = ShopDashboardNavigation();
      final ready = Stream.value(
        StayBookingReadiness(
          [
            {'id': 't'},
          ],
          [
            {'id': 'r', 'roomTypeId': 't', 'enabled': true},
          ],
        ),
      );
      var result = {
        for (final key in ShopIntroContent.keys)
          key: ShopIntroContentStatus.empty,
      };
      var reads = 0;
      Widget screen(String user) => MaterialApp(
        home: ShopDashboardNavigationScope(
          navigation: nav,
          desktop: true,
          openEntry: (_) async {},
          child: ShopDashboardContentNavigator(
            navigation: nav,
            child: Scaffold(
              body: SingleChildScrollView(
                child: ShopOpeningProgress(
                  shopId: 's',
                  userId: user,
                  shop: const {
                    'phoneSetupCompleted': true,
                    'addressSetupCompleted': true,
                    'bookingEnabled': true,
                  },
                  readinessStream: ready,
                  loadStayPolicy: () async => true,
                  loadIntroStatus: (_) async {
                    reads++;
                    return Map.of(result);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen('u'));
      await tester.pumpAndSettle();
      expect(find.text('環境介紹'), findsOneWidget);
      Future<void> visit() async {
        await nav.switchTo(
          id: 'fixture',
          page: (_) => const Scaffold(body: Text('草稿')),
        );
        await tester.pumpAndSettle();
        await nav.switchTo();
        await tester.pumpAndSettle();
      }

      await visit();
      expect(find.text('環境介紹'), findsOneWidget);
      result['environment'] = ShopIntroContentStatus.configured;
      await visit();
      expect(find.text('環境介紹'), findsNothing);
      expect(find.text('關於我們管理'), findsOneWidget);
      result['environment'] = ShopIntroContentStatus.empty;
      result['about'] = ShopIntroContentStatus.configured;
      await visit();
      expect(find.text('環境介紹'), findsNothing);
      expect(find.text('關於我們管理'), findsNothing);
      Finder skip(String title) => find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(OutlinedButton),
        ),
        matching: find.text('稍後再說'),
      );
      await tester.ensureVisible(skip('公告管理'));
      await tester.tap(skip('公告管理'));
      await tester.pumpAndSettle();
      expect(find.text('公告管理'), findsNothing);
      await tester.ensureVisible(skip('常見問題管理'));
      await tester.tap(skip('常見問題管理'));
      await tester.pumpAndSettle();
      expect(find.text('豐富你的店家介紹'), findsNothing);
      final persisted = await ShopIntroGuideProgress.load('s', 'u');
      expect(persisted.completed, {'environment', 'about'});
      expect(persisted.skipped, {'announcement', 'faq'});
      final before = reads;
      result = {
        for (final key in ShopIntroContent.keys)
          key: ShopIntroContentStatus.empty,
      };
      await tester.pumpWidget(screen('relogin'));
      await tester.pumpAndSettle();
      ShopIntroContent.notifyReturned('s');
      await tester.pumpAndSettle();
      expect(reads, before);
      expect(find.text('豐富你的店家介紹'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      nav.dispose();
    }
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('尚未發布的有效資料直接結束該項，全區稍後不偽造完成', (tester) async {
    final ready = Stream.value(StayBookingReadiness([], []));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShopOpeningProgress(
              shopId: 'drafts',
              userId: 'u',
              shop: const {
                'phoneSetupCompleted': true,
                'addressSetupCompleted': true,
              },
              readinessStream: ready,
              loadStayPolicy: () async => false,
              loadIntroStatus: (_) async => {
                'environment': ShopIntroContentStatus.empty,
                'about': ShopIntroContentStatus.empty,
                'announcement': ShopIntroContentStatus.unpublished,
                'faq': ShopIntroContentStatus.unpublished,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('公告管理'), findsNothing);
    expect(find.text('常見問題管理'), findsNothing);
    await tester.tap(find.text('稍後再說'));
    await tester.pumpAndSettle();
    expect(find.text('豐富你的店家介紹'), findsNothing);
    final p = await ShopIntroGuideProgress.load('drafts', 'u');
    expect(p.dismissed, isTrue);
    expect(p.completed, {'announcement', 'faq'});
    expect(p.completed.contains('environment'), isFalse);
  });
  testWidgets('初次讀取與錯誤不當空白，切店不沿用舊回呼', (tester) async {
    final old = Completer<Map<String, ShopIntroContentStatus>>();
    Future<void> screen(String shop) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShopOpeningProgress(
                shopId: shop,
                userId: 'u',
                shop: const {
                  'phoneSetupCompleted': true,
                  'addressSetupCompleted': true,
                },
                readinessStream: Stream.value(StayBookingReadiness([], [])),
                loadStayPolicy: () async => false,
                loadIntroStatus: (id) => id == 'old'
                    ? old.future
                    : Future.value({
                        for (final key in ShopIntroContent.keys)
                          key: ShopIntroContentStatus.failed,
                      }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await screen('old');
    expect(find.text('豐富你的店家介紹'), findsNothing);
    await screen('new');
    old.complete({
      for (final key in ShopIntroContent.keys)
        key: ShopIntroContentStatus.configured,
    });
    await tester.pumpAndSettle();
    expect(find.text('暫時無法確認'), findsNWidgets(4));
    expect((await ShopIntroGuideProgress.load('new', 'u')).completed, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('前台四種摘要空資料不展示示意內容，有效介紹保留', (tester) async {
    final theme = HomeThemeModel.classicDefault;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ModernHomeAboutSection(
                  theme: theme,
                  setting: const HomeAboutSectionSetting(),
                  shop: const {},
                  environmentIntro: const {},
                  shopName: '真店名',
                  logoUrl: '',
                  preview: false,
                  onOpen: () {},
                ),
                ModernHomeEnvironmentSection(
                  theme: theme,
                  setting: const HomeEnvironmentSectionSetting(),
                  environmentIntro: const {},
                  facilityKeys: const [],
                  preview: false,
                  onOpen: () {},
                ),
                ModernHomeFaqSection(
                  theme: theme,
                  setting: const HomeFaqSectionSetting(),
                  items: const [],
                  phase: HomeInfoSectionPhase.empty,
                  onOpen: () {},
                ),
                ModernHomeNewsSection(
                  theme: theme,
                  setting: const HomeNewsSectionSetting(),
                  items: const [],
                  phase: HomeNewsSectionPhase.empty,
                  preview: false,
                  onOpen: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
