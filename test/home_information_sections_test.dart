import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_layout_canvas.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/faq_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_layout_option_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/policy_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_appearance_tabs.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_faq_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_policy_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_review_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const HomeRoomSectionSetting rooms = HomeRoomSectionSetting(
    layout: HomeRoomSectionLayouts.simpleEntry,
    simple: HomeRoomSimpleSetting(cardSize: HomeRoomSimpleCardSizes.small),
  );
  const HomeEnvironmentSectionSetting environment =
      HomeEnvironmentSectionSetting();

  HomeSectionSpan span(String id, HomeInformationSectionsSetting info) {
    return homeSectionSpan(
      sectionId: id,
      rooms: rooms,
      environment: environment,
      information: info,
    );
  }

  test('settings round-trip and illegal layouts fall back', () {
    const HomeInformationSectionsSetting original =
        HomeInformationSectionsSetting(
          policy: HomePolicySectionSetting(
            showOnHome: true,
            layout: HomePolicyLayouts.summary,
            title: '須知',
            subtitle: '請先閱讀',
            keepServiceEntry: false,
            summaryItemCount: 2,
          ),
          faq: HomeFaqSectionSetting(
            showOnHome: true,
            layout: HomeFaqLayouts.preview,
            previewCount: 3,
          ),
          reviews: HomeReviewSectionSetting(
            showOnHome: false,
            layout: HomeReviewLayouts.scoreCompact,
            carouselCount: 4,
          ),
        );
    final HomeInformationSectionsSetting loaded =
        HomeInformationSectionsSetting.fromMap(original.toMap());
    expect(loaded.policy.showOnHome, isTrue);
    expect(loaded.policy.layout, HomePolicyLayouts.summary);
    expect(loaded.policy.keepServiceEntry, isFalse);
    expect(loaded.faq.previewCount, 3);
    expect(loaded.reviews.layout, HomeReviewLayouts.scoreCompact);
    expect(loaded.reviews.carouselCount, 4);
    expect(
      loaded
          .copyWith(policy: loaded.policy.copyWith(showOnHome: false))
          .policy
          .showOnHome,
      isFalse,
    );
    expect(
      HomePolicySectionSetting.fromMap(<String, dynamic>{
        'layout': 'poster',
      }).layout,
      HomePolicyLayouts.compact,
    );
    expect(
      HomeFaqSectionSetting.fromMap(<String, dynamic>{'layout': 'grid'}).layout,
      HomeFaqLayouts.compact,
    );
    expect(
      HomeReviewSectionSetting.fromMap(<String, dynamic>{
        'layout': 'marquee',
      }).layout,
      HomeReviewLayouts.carousel,
    );
  });

  test('counts, titles and old data keep the current review carousel', () {
    expect(HomeFaqSectionSetting.migratePreviewCount(1), 2);
    expect(HomeFaqSectionSetting.migratePreviewCount(3), 3);
    expect(HomeFaqSectionSetting.migratePreviewCount(4), 4);
    expect(HomeFaqSectionSetting.migratePreviewCount(9), 5);
    expect(HomeReviewSectionSetting.migrateCarouselCount(1), 2);
    expect(HomeReviewSectionSetting.migrateCarouselCount(5), 5);
    expect(HomeReviewSectionSetting.migrateCarouselCount(8), 5);
    expect(HomePolicySectionSetting.migrateSummaryCount(2), 2);
    expect(HomePolicySectionSetting.migrateSummaryCount(4), 3);
    final HomeInformationSectionsSetting legacy =
        HomeInformationSectionsSetting.fromMap(null);
    expect(legacy.reviews.showOnHome, isTrue);
    expect(legacy.reviews.layout, HomeReviewLayouts.carousel);
    expect(legacy.reviews.keepServiceEntry, isTrue);
    expect(legacy.policy.showOnHome, isFalse);
    expect(legacy.faq.showOnHome, isFalse);
    expect(legacy.policy.keepServiceEntry, isTrue);
    expect(legacy.faq.keepServiceEntry, isTrue);
    expect(
      HomePolicySectionSetting.fromMap(<String, dynamic>{
        'title': '標' * 20,
        'subtitle': '副' * 40,
      }).toMap()['title'],
      '標' * 12,
    );
  });

  test('spans and pairing use the shared half row', () {
    const HomeInformationSectionsSetting compact =
        HomeInformationSectionsSetting(
          policy: HomePolicySectionSetting(layout: HomePolicyLayouts.compact),
          faq: HomeFaqSectionSetting(layout: HomeFaqLayouts.compact),
          reviews: HomeReviewSectionSetting(
            layout: HomeReviewLayouts.scoreCompact,
          ),
        );
    expect(span('policy', compact), HomeSectionSpan.half);
    expect(span('faq', compact), HomeSectionSpan.half);
    expect(span('reviews', compact), HomeSectionSpan.half);
    expect(
      span(
        'policy',
        const HomeInformationSectionsSetting(
          policy: HomePolicySectionSetting(layout: HomePolicyLayouts.summary),
        ),
      ),
      HomeSectionSpan.full,
    );
    expect(
      span(
        'faq',
        const HomeInformationSectionsSetting(
          faq: HomeFaqSectionSetting(layout: HomeFaqLayouts.preview),
        ),
      ),
      HomeSectionSpan.full,
    );
    expect(
      span('reviews', const HomeInformationSectionsSetting()),
      HomeSectionSpan.full,
    );
    expect(
      span(
        'policy',
        const HomeInformationSectionsSetting(
          policy: HomePolicySectionSetting(
            layout: HomePolicyLayouts.serviceSplit,
          ),
        ),
      ),
      HomeSectionSpan.full,
    );
    expect(
      span(
        'faq',
        const HomeInformationSectionsSetting(
          faq: HomeFaqSectionSetting(layout: HomeFaqLayouts.horizontalCards),
        ),
      ),
      HomeSectionSpan.full,
    );
    expect(
      span(
        'faq',
        const HomeInformationSectionsSetting(
          faq: HomeFaqSectionSetting(layout: HomeFaqLayouts.twoColumnCards),
        ),
      ),
      HomeSectionSpan.full,
    );
    expect(
      span(
        'reviews',
        const HomeInformationSectionsSetting(
          reviews: HomeReviewSectionSetting(
            layout: HomeReviewLayouts.scoreOverview,
          ),
        ),
      ),
      HomeSectionSpan.full,
    );
    expect(
      span(
        'reviews',
        const HomeInformationSectionsSetting(
          reviews: HomeReviewSectionSetting(
            layout: HomeReviewLayouts.scoreAndLatest,
          ),
        ),
      ),
      HomeSectionSpan.full,
    );
    final List<HomeSectionRow> rows = packHomeSections(<String>[
      'rooms',
      'policy',
      'faq',
      'reviews',
    ], (String id) => span(id, compact));
    expect(rows.map((HomeSectionRow row) => row.sectionIds), <List<String>>[
      <String>['rooms', 'policy'],
      <String>['faq', 'reviews'],
    ]);
  });

  test('old section order gains policy and faq without losing saved order', () {
    const List<String> saved = <String>[
      'rooms',
      'banners',
      'services',
      'reviews',
      'about',
    ];
    final List<String> next = HomeSectionOrder.normalize(saved);
    expect(next.toSet().length, next.length);
    expect(next.toSet(), HomeSectionOrder.defaultOrder.toSet());
    expect(next.indexOf('rooms'), lessThan(next.indexOf('banners')));
    expect(next.indexOf('services'), lessThan(next.indexOf('policy')));
    expect(next.indexOf('policy'), lessThan(next.indexOf('faq')));
    expect(next.indexOf('faq'), lessThan(next.indexOf('reviews')));
    final List<String> hidden = HomeSectionOrder.visible(
      next,
      showAnnouncements: true,
      showPolicy: false,
      showFaq: false,
      showReviews: false,
    );
    expect(hidden.contains('policy'), isFalse);
    expect(hidden.contains('faq'), isFalse);
    expect(hidden.contains('reviews'), isFalse);
    expect(next.contains('policy'), isTrue);
    expect(
      packHomeSections(hidden, (_) => HomeSectionSpan.half).any(
        (HomeSectionRow row) =>
            row.sectionIds.contains('policy') ||
            row.sectionIds.contains('reviews'),
      ),
      isFalse,
    );
  });

  test('empty live sections stay out and preview still shows a sample', () {
    expect(
      resolveHomeInfoPhase(
        showOnHome: true,
        editorPreview: false,
        ready: true,
        failed: false,
        hasContent: false,
      ),
      HomeInfoSectionPhase.hidden,
    );
    expect(
      resolveHomeInfoPhase(
        showOnHome: true,
        editorPreview: true,
        ready: true,
        failed: false,
        hasContent: false,
      ),
      HomeInfoSectionPhase.empty,
    );
    expect(
      resolveHomeInfoPhase(
        showOnHome: true,
        editorPreview: false,
        featureEnabled: false,
        ready: true,
        failed: false,
        hasContent: true,
      ),
      HomeInfoSectionPhase.hidden,
    );
    expect(homeInfoOccupiesSection(HomeInfoSectionPhase.hidden), isFalse);
    expect(readHomePolicySnapshot(null).hasContent, isFalse);
    expect(
      readHomePolicySnapshot(<String, dynamic>{
        'version': 4,
        'enabled': <String, dynamic>{'checkinTime': true, 'facility': false},
        'sections': <String, dynamic>{
          'checkinTime': '上午可入住',
          'facility': '不應出現',
        },
      }).titles,
      <String>['營業時間與環境參觀時間'],
    );
    expect(
      readHomePolicySnapshot(<String, dynamic>{
        'version': 4,
        'enabled': <String, dynamic>{'checkinTime': true},
        'sections': <String, dynamic>{'checkinTime': '上午可入住'},
      }).coverageLabel,
      '住宿適用',
    );
    final List<HomeFaqItem> faqs = homeFaqsFromMaps(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'draft',
        'question': '未發布',
        'isPublished': false,
        'sortOrder': 0,
      },
      <String, dynamic>{
        'id': 'b',
        'question': '第二題',
        'isPublished': true,
        'sortOrder': 2,
      },
      <String, dynamic>{
        'id': 'a',
        'question': '第一題',
        'isPublished': true,
        'sortOrder': 1,
      },
    ]);
    expect(faqs.map((HomeFaqItem item) => item.id), <String>['a', 'b']);
    final List<ReviewModel> reviews = sortPublicReviews(<ReviewModel>[
      _review(id: 'old', createdAt: DateTime(2026, 1, 1)),
      _review(id: 'hidden', status: 'hidden', createdAt: DateTime(2026, 3, 1)),
      _review(id: 'new', createdAt: DateTime(2026, 2, 1)),
    ]);
    expect(reviews.map((ReviewModel review) => review.reviewId), <String>[
      'new',
      'old',
    ]);
  });

  test(
    'service shortcuts follow keepServiceEntry and the FAQ feature switch',
    () {
      expect(showPolicyServiceEntry(const HomePolicySectionSetting()), isTrue);
      expect(
        showPolicyServiceEntry(
          const HomePolicySectionSetting(keepServiceEntry: false),
        ),
        isFalse,
      );
      expect(
        showFaqServiceEntry(
          const HomeFaqSectionSetting(),
          featureEnabled: true,
        ),
        isTrue,
      );
      expect(
        showFaqServiceEntry(
          const HomeFaqSectionSetting(),
          featureEnabled: false,
        ),
        isFalse,
      );
      expect(
        showReviewServiceEntry(
          const HomeReviewSectionSetting(keepServiceEntry: false),
        ),
        isFalse,
      );
    },
  );

  test('preview and the live homepage share the same renderers', () {
    final String page = File(
      'lib/features/shop/pages/shop_public_modern_page.dart',
    ).readAsStringSync();
    expect(page.contains('ModernHomePolicySection('), isTrue);
    expect(page.contains('ModernHomeFaqSection('), isTrue);
    expect(page.contains('ModernReviewSection('), isTrue);
    expect(page.contains("collection('reviews')"), isTrue);
    final String reviewWidget = File(
      'lib/features/shop/widgets/modern_home/modern_review_section.dart',
    ).readAsStringSync();
    expect(reviewWidget.contains("collection('reviews')"), isFalse);
    expect(ModernHomeAppearanceTabs.quickBooking, 6);
    expect(ModernHomeAppearanceTabs.policy, 7);
    expect(ModernHomeAppearanceTabs.faq, 8);
    expect(ModernHomeAppearanceTabs.reviews, 9);
    expect(ModernHomeAppearanceTabs.navigation, 10);
    expect(ModernHomeAppearanceTabs.features, 11);
    expect(ModernHomeAppearanceTabs.length, 12);
    expect(
      ModernHomeAppearanceTabs.sectionTab('policy'),
      ModernHomeAppearanceTabs.policy,
    );
    expect(
      ModernHomeAppearanceTabs.sectionTab('faq'),
      ModernHomeAppearanceTabs.faq,
    );
    expect(
      ModernHomeAppearanceTabs.sectionTab('reviews'),
      ModernHomeAppearanceTabs.reviews,
    );
    final String theme = File(
      'lib/features/shop/pages/shop_theme_setting_page.dart',
    ).readAsStringSync();
    expect(theme.contains('資訊與信任'), isFalse);
    expect(theme.contains('_buildInformationPane'), isFalse);
    expect(theme.contains('isScrollable: true'), isTrue);
    expect(theme.contains('tabAlignment: TabAlignment.start'), isTrue);
    expect(theme.contains('TabAlignment.fill'), isFalse);
    expect(theme.contains('_homeSectionOrder'), isTrue);
    final int tabStart = theme.indexOf('void _onTabChanged()');
    final int tabEnd = theme.indexOf('void _bindModernDraftListeners()');
    final String tabChanged = theme.substring(tabStart, tabEnd);
    expect(tabChanged.contains('_homeSectionOrder'), isFalse);
    expect(
      theme.contains('animateTo(ModernHomeAppearanceTabs.features)'),
      isTrue,
    );
    expect(
      theme.contains("'informationSections': _informationSections.toMap()"),
      isTrue,
    );
  });

  testWidgets('narrow cards keep their height and do not overflow', (
    WidgetTester tester,
  ) async {
    final String longText = '很長的入住說明與評價內容' * 8;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ListView(
              children: <Widget>[
                ModernHomePolicySection(
                  theme: HomeThemeModel.modernDefault,
                  setting: const HomePolicySectionSetting(
                    showOnHome: true,
                    layout: HomePolicyLayouts.compact,
                    subtitle: '入住前請先閱讀相關規定，這段副標會被省略',
                  ),
                  snapshot: const HomePolicySnapshot(
                    version: 4,
                    coverageLabel: '住宿適用',
                    titles: <String>['營業時間與環境參觀時間'],
                  ),
                  phase: HomeInfoSectionPhase.ready,
                  onOpen: (_) {},
                ),
                ModernHomeFaqSection(
                  theme: HomeThemeModel.modernDefault,
                  setting: const HomeFaqSectionSetting(
                    showOnHome: true,
                    layout: HomeFaqLayouts.preview,
                    previewCount: 2,
                  ),
                  items: <HomeFaqItem>[
                    HomeFaqItem(
                      id: '1',
                      question: longText,
                      answer: longText,
                      sortOrder: 1,
                    ),
                  ],
                  phase: HomeInfoSectionPhase.ready,
                  onOpen: () {},
                ),
                ModernReviewSection(
                  theme: HomeThemeModel.modernDefault,
                  setting: const HomeReviewSectionSetting(
                    layout: HomeReviewLayouts.carousel,
                    carouselCount: 2,
                  ),
                  reviews: <ReviewModel>[
                    _review(id: 'a', content: longText),
                    _review(id: 'b', content: longText),
                  ],
                  phase: HomeInfoSectionPhase.ready,
                  onOpen: () {},
                ),
                ModernHomePolicySection(
                  theme: HomeThemeModel.modernDefault,
                  setting: const HomePolicySectionSetting(
                    showOnHome: true,
                    layout: HomePolicyLayouts.summary,
                  ),
                  snapshot: const HomePolicySnapshot(),
                  phase: HomeInfoSectionPhase.empty,
                  onOpen: (_) {},
                ),
                ModernReviewSection(
                  theme: HomeThemeModel.modernDefault,
                  setting: const HomeReviewSectionSetting(
                    layout: HomeReviewLayouts.featured,
                  ),
                  reviews: const <ReviewModel>[],
                  phase: HomeInfoSectionPhase.empty,
                  onOpen: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('示意：入住時間'), findsOneWidget);
    expect(find.text('示意評價：環境乾淨，照顧很細心。'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home-policy-card')).first).height,
      closeTo(kModernHomeSmallCardHeight, 0.5),
    );
    expect(
      tester.getSize(find.text('示意評價：環境乾淨，照顧很細心。')).height,
      greaterThan(12),
    );
  });

  testWidgets('FAQ lock and the hidden-entry reminder are visible', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FaqSectionSettingsPanel(
            setting: const HomeInformationSectionsSetting(),
            theme: HomeThemeModel.modernDefault,
            locked: true,
            onChanged: (_) {},
            onOpenFeatures: () => opens++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(kHomeFaqLockedMessage), findsOneWidget);
    expect(find.text('前往前台功能'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-faq-open-features')));
    await tester.pump();
    expect(opens, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PolicySectionSettingsPanel(
            setting: const HomeInformationSectionsSetting(
              policy: HomePolicySectionSetting(
                showOnHome: false,
                keepServiceEntry: false,
              ),
            ),
            theme: HomeThemeModel.modernDefault,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(kHomeInfoHiddenEntryMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('new layouts and fields keep older saved values', () {
    final HomePolicySectionSetting policy =
        HomePolicySectionSetting.fromMap(<String, dynamic>{
          'showOnHome': true,
          'layout': HomePolicyLayouts.serviceSplit,
          'title': '入住須知',
          'subtitle': '請先看',
          'keepServiceEntry': false,
          'summaryItemCount': 2,
        });
    expect(policy.layout, HomePolicyLayouts.serviceSplit);
    expect(policy.showOnHome, isTrue);
    expect(policy.keepServiceEntry, isFalse);
    expect(policy.summaryItemCount, 2);
    expect(policy.showVersion, isTrue);
    expect(policy.showCoverage, isTrue);
    expect(policy.toMap()['layout'], HomePolicyLayouts.serviceSplit);

    final HomeFaqSectionSetting faq = HomeFaqSectionSetting.fromMap(
      <String, dynamic>{
        'layout': HomeFaqLayouts.horizontalCards,
        'previewCount': 4,
        'showOnHome': true,
      },
    );
    expect(faq.layout, HomeFaqLayouts.horizontalCards);
    expect(faq.previewCount, 4);
    expect(faq.showAnswerPreview, isFalse);
    expect(faq.showQuestionCount, isTrue);
    expect(faq.showViewAll, isTrue);
    expect(faq.leadingStyle, HomeFaqLeadingStyles.icon);
    expect(
      HomeFaqSectionSetting.fromMap(<String, dynamic>{
        'layout': HomeFaqLayouts.twoColumnCards,
        'leadingStyle': HomeFaqLeadingStyles.number,
        'showAnswerPreview': true,
      }).copyWith(previewCount: 5).previewCount,
      5,
    );

    final HomeReviewSectionSetting reviews =
        HomeReviewSectionSetting.fromMap(<String, dynamic>{
          'layout': HomeReviewLayouts.scoreOverview,
          'carouselCount': 3,
          'showOnHome': false,
        });
    expect(reviews.layout, HomeReviewLayouts.scoreOverview);
    expect(reviews.showOnHome, isFalse);
    expect(reviews.carouselCount, 3);
    expect(reviews.showCustomerName, isTrue);
    expect(reviews.showImages, isFalse);
    expect(
      HomeReviewSectionSetting.fromMap(<String, dynamic>{
        'layout': HomeReviewLayouts.scoreAndLatest,
      }).layout,
      HomeReviewLayouts.scoreAndLatest,
    );
    expect(HomeReviewLayouts.badge(HomeReviewLayouts.scoreAndLatest), '推薦');
    expect(const HomeReviewSectionSetting().layout, HomeReviewLayouts.carousel);
  });

  testWidgets('layout cards stay wide on desktop and full width on a phone', (
    WidgetTester tester,
  ) async {
    Future<void> pump(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: width,
                child: HomeSectionLayoutPicker(
                  theme: HomeThemeModel.modernDefault,
                  selectedId: HomePolicyLayouts.compact,
                  onSelected: (_) {},
                  choices: <HomeSectionLayoutChoice>[
                    for (final String layout in HomePolicyLayouts.all)
                      HomeSectionLayoutChoice(
                        id: layout,
                        title: HomePolicyLayouts.label(layout),
                        description: HomePolicyLayouts.description(layout),
                        badge: HomePolicyLayouts.badge(layout),
                        preview: const SizedBox(height: 24),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(860);
    final double desktopWidth = tester
        .getSize(find.byKey(const Key('info-layout-compact')))
        .width;
    expect(desktopWidth, greaterThan(300));
    expect(tester.takeException(), isNull);

    await pump(360);
    final double phoneWidth = tester
        .getSize(find.byKey(const Key('info-layout-serviceSplit')))
        .width;
    expect(phoneWidth, greaterThan(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging policy updates order without a framework assertion', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    try {
      final _InfoDragHost host = _InfoDragHost();
      await tester.pumpWidget(host);
      await tester.pump();
      final _InfoDragHostState state = tester.state<_InfoDragHostState>(
        find.byType(_InfoDragHost),
      );
      expect(find.byTooltip('拖曳整個入住須知區塊'), findsOneWidget);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('home-section-drag-policy'))),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 20));
      final Rect rooms = tester.getRect(
        find.byKey(const ValueKey<String>('home-section-rooms')),
      );
      await gesture.moveTo(Offset(rooms.left + 12, rooms.top - 28));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(state.selected, 'policy');
      expect(state.order.first, 'policy');
      expect(state.order.toSet().length, state.order.length);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

ReviewModel _review({
  required String id,
  String content = '住得很安心',
  String status = 'visible',
  DateTime? createdAt,
}) {
  final Timestamp? time = createdAt == null
      ? null
      : Timestamp.fromDate(createdAt);
  return ReviewModel(
    reviewId: id,
    shopId: 'shop',
    bookingId: 'booking',
    userId: 'user',
    customerName: '小明',
    petNames: const <String>[],
    roomTypeName: '標準房',
    startDate: null,
    endDate: null,
    nights: 1,
    rating: 5,
    environmentRating: 5,
    serviceRating: 5,
    priceRating: 5,
    content: content,
    imageUrls: const <String>[],
    reply: '',
    replyAt: null,
    replyBy: '',
    status: status,
    createdAt: time,
    updatedAt: time,
  );
}

class _InfoDragHost extends StatefulWidget {
  const _InfoDragHost();

  @override
  State<_InfoDragHost> createState() => _InfoDragHostState();
}

class _InfoDragHostState extends State<_InfoDragHost> {
  List<String> order = <String>['rooms', 'policy'];
  String? selected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 640,
          child: HomeLayoutCanvas(
            background: Colors.white,
            sectionIds: order,
            sectionOrder: order,
            spanOf: (_) => HomeSectionSpan.half,
            pinFooter: false,
            shopInfo: null,
            bottomInset: 12,
            selectedSectionId: selected,
            onSelectSection: (String sectionId) {
              setState(() => selected = sectionId);
            },
            onSectionOrderChanged: (List<String> next) {
              setState(() => order = next);
            },
            focusSectionId: null,
            focusSectionToken: 0,
            buildSection: (String sectionId) {
              return ModernHomeEntryCard(
                cardKey: Key('card-$sectionId'),
                theme: HomeThemeModel.modernDefault,
                title: sectionId,
                subtitle: '副標',
                showSubtitle: true,
                cardSize: 'small',
                surface: 'filled',
                icon: Icons.pets_outlined,
                onTap: () {},
              );
            },
          ),
        ),
      ),
    );
  }
}
