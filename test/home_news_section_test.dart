import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_layout_canvas.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_news_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/news_section_settings_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const HomeRoomSectionSetting rooms = HomeRoomSectionSetting();
  const HomeEnvironmentSectionSetting environment =
      HomeEnvironmentSectionSetting();

  HomeSectionSpan span(String sectionId, HomeNewsSectionSetting news) {
    return homeSectionSpan(
      sectionId: sectionId,
      rooms: rooms,
      environment: environment,
      news: news,
    );
  }

  test('old shops without newsSection load the default single-line card', () {
    final HomeNewsSectionSetting setting = HomeNewsSectionSetting.fromMap(null);
    expect(setting.layout, HomeNewsLayouts.singleLine);
    expect(setting.source, HomeNewsSources.both);
    expect(setting.title, '最新消息');
    expect(setting.multiLineCount, 3);
    expect(setting.showSummary, isTrue);
    expect(setting.showDate, isFalse);
    expect(setting.showTypeBadge, isTrue);
    expect(setting.showArrow, isTrue);
    expect(setting.surfaceStyle, HomeNewsSurfaces.solid);
    expect(setting.textAlign, HomeNewsTextAligns.left);
    expect(setting.toMap()['title'], '最新消息');
  });

  test('illegal layout and source fall back to defaults', () {
    final HomeNewsSectionSetting setting =
        HomeNewsSectionSetting.fromMap(<String, dynamic>{
          'layout': 'carousel',
          'source': 'promotion',
          'title': '   ',
          'surfaceStyle': 'glow',
          'textAlign': 'justify',
        });
    expect(setting.layout, HomeNewsLayouts.singleLine);
    expect(setting.source, HomeNewsSources.both);
    expect(setting.title, '最新消息');
    expect(setting.surfaceStyle, HomeNewsSurfaces.solid);
    expect(setting.textAlign, HomeNewsTextAligns.left);
  });

  test('multiLineCount only accepts 2 or 3', () {
    expect(HomeNewsSectionSetting.migrateCount(2), 2);
    expect(HomeNewsSectionSetting.migrateCount(3), 3);
    expect(HomeNewsSectionSetting.migrateCount(1), 3);
    expect(HomeNewsSectionSetting.migrateCount(4), 3);
    expect(HomeNewsSectionSetting.migrateCount('2'), 2);
    expect(HomeNewsSectionSetting.migrateCount('nine'), 3);
    expect(
      HomeNewsSectionSetting.fromMap(<String, dynamic>{
        'multiLineCount': 9,
      }).multiLineCount,
      3,
    );
    expect(
      HomeNewsSectionSetting.fromMap(<String, dynamic>{
        'title': '標' * 30,
      }).title.length,
      24,
    );
  });

  test('compact cards are half and the other news layouts are full', () {
    expect(
      span(
        'announcements',
        const HomeNewsSectionSetting(layout: HomeNewsLayouts.compactCard),
      ),
      HomeSectionSpan.half,
    );
    expect(
      span(
        'announcements',
        const HomeNewsSectionSetting(layout: HomeNewsLayouts.singleLine),
      ),
      HomeSectionSpan.full,
    );
    expect(
      span(
        'announcements',
        const HomeNewsSectionSetting(layout: HomeNewsLayouts.multiLine),
      ),
      HomeSectionSpan.full,
    );
    expect(
      span('announcements', const HomeNewsSectionSetting()),
      HomeSectionSpan.full,
    );
  });

  test('a compact news card pairs with another half card', () {
    final HomeRoomSectionSetting smallRooms = HomeRoomSectionSetting(
      layout: HomeRoomSectionLayouts.simpleEntry,
      simple: const HomeRoomSimpleSetting(
        cardSize: HomeRoomSimpleCardSizes.small,
      ),
    );
    const HomeNewsSectionSetting news = HomeNewsSectionSetting(
      layout: HomeNewsLayouts.compactCard,
    );
    final List<HomeSectionRow> rows = packHomeSections(
      <String>['rooms', 'announcements', 'reviews'],
      (String sectionId) => homeSectionSpan(
        sectionId: sectionId,
        rooms: smallRooms,
        environment: environment,
        news: news,
      ),
    );
    expect(rows.first.sectionIds, <String>['rooms', 'announcements']);
    expect(rows.first.span, HomeSectionSpan.half);
    expect(rows.last.sectionIds, <String>['reviews']);
  });

  test('the live homepage drops an empty news section before packing', () {
    const HomeNewsSectionPhase hidden = HomeNewsSectionPhase.hidden;
    expect(homeNewsOccupiesSection(hidden), isFalse);
    final List<String> visible = HomeSectionOrder.visible(
      HomeSectionOrder.defaultOrder,
      showAnnouncements: false,
    );
    expect(visible, isNot(contains('announcements')));
    final List<HomeSectionRow> rows = packHomeSections(visible, (String id) {
      return id == 'announcements'
          ? HomeSectionSpan.half
          : HomeSectionSpan.full;
    });
    expect(
      rows.any(
        (HomeSectionRow row) => row.sectionIds.contains('announcements'),
      ),
      isFalse,
    );
  });

  test('notices, campaigns, and both keep their own source and pin order', () {
    final List<HomeNewsItem> notices = HomeNewsItem.noticesFromMaps(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'draft',
          'title': '未發布',
          'content': '不該出現',
          'isPublished': false,
          'isPinned': true,
          'createdAt': DateTime(2026, 4, 1),
          'type': 'important',
        },
        <String, dynamic>{
          'id': 'old',
          'title': '舊公告',
          'content': '舊摘要',
          'isPublished': true,
          'isPinned': false,
          'createdAt': DateTime(2026, 1, 1),
          'type': 'normal',
        },
        <String, dynamic>{
          'id': 'pinned',
          'title': '置頂公告',
          'content': '置頂摘要',
          'isPublished': true,
          'isPinned': true,
          'createdAt': DateTime(2025, 1, 1),
          'type': 'promotion',
        },
      ],
    );
    final List<HomeNewsItem> campaigns = <HomeNewsItem>[
      HomeNewsItem.campaign(
        _campaign(id: 'sale', name: '連住優惠', createdAt: DateTime(2026, 3, 1)),
      ),
    ];

    final List<HomeNewsItem> onlyNotices = mergeHomeNews(
      source: HomeNewsSources.notices,
      notices: notices,
      campaigns: campaigns,
    );
    expect(onlyNotices.map((HomeNewsItem item) => item.id), <String>[
      'pinned',
      'old',
    ]);
    expect(onlyNotices.every((HomeNewsItem item) => !item.isCampaign), isTrue);

    final List<HomeNewsItem> onlyCampaigns = mergeHomeNews(
      source: HomeNewsSources.campaigns,
      notices: notices,
      campaigns: campaigns,
    );
    expect(onlyCampaigns.single.id, 'sale');
    expect(onlyCampaigns.single.sourceType, HomeNewsSources.campaigns);
    expect(onlyCampaigns.single.summary, '活動說明');

    final List<HomeNewsItem> both = mergeHomeNews(
      source: HomeNewsSources.both,
      notices: notices,
      campaigns: campaigns,
    );
    expect(both.map((HomeNewsItem item) => item.id), <String>[
      'pinned',
      'sale',
      'old',
    ]);
    expect(both.first.pinned, isTrue);
    expect(both[1].isCampaign, isTrue);
  });

  test('feature off and empty live states stay hidden', () {
    const HomeNewsLoadState ready = HomeNewsLoadState(
      noticesReady: true,
      campaignsReady: true,
    );
    expect(
      resolveHomeNewsPhase(
        featureEnabled: false,
        editorPreview: false,
        source: HomeNewsSources.both,
        load: ready,
        hasItems: true,
      ),
      HomeNewsSectionPhase.hidden,
    );
    expect(
      resolveHomeNewsPhase(
        featureEnabled: true,
        editorPreview: false,
        source: HomeNewsSources.both,
        load: ready,
        hasItems: false,
      ),
      HomeNewsSectionPhase.hidden,
    );
    expect(
      resolveHomeNewsPhase(
        featureEnabled: true,
        editorPreview: true,
        source: HomeNewsSources.both,
        load: ready,
        hasItems: false,
      ),
      HomeNewsSectionPhase.empty,
    );
    expect(
      resolveHomeNewsPhase(
        featureEnabled: true,
        editorPreview: true,
        source: HomeNewsSources.notices,
        load: const HomeNewsLoadState(
          noticesReady: true,
          noticesFailed: true,
          campaignsReady: true,
        ),
        hasItems: false,
      ),
      HomeNewsSectionPhase.unavailable,
    );
  });

  testWidgets('preview keeps an empty hint and live taps open the right tab', (
    WidgetTester tester,
  ) async {
    ShopAnnouncementSection? opened;
    await tester.pumpWidget(
      _newsApp(
        setting: const HomeNewsSectionSetting(
          layout: HomeNewsLayouts.compactCard,
        ),
        items: const <HomeNewsItem>[],
        phase: HomeNewsSectionPhase.empty,
        preview: true,
        onOpen: (ShopAnnouncementSection section) => opened = section,
      ),
    );
    expect(find.text(kHomeNewsEmptyMessage), findsOneWidget);
    expect(find.text('最新消息'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-news-card')));
    await tester.pump();
    expect(opened, isNull);
    expect(
      tester.getSize(find.byKey(const Key('home-news-card'))).height,
      closeTo(kModernHomeSmallCardHeight, 0.5),
    );

    opened = null;
    await tester.pumpWidget(
      _newsApp(
        setting: const HomeNewsSectionSetting(),
        items: <HomeNewsItem>[
          _notice(id: 'n1', title: '店家公告標題'),
          _campaignItem(id: 'c1', title: '優惠活動標題'),
        ],
        phase: HomeNewsSectionPhase.ready,
        preview: false,
        onOpen: (ShopAnnouncementSection section) => opened = section,
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('home-news-card'))).height,
      closeTo(kModernHomeWideCardHeight, 0.5),
    );
    await tester.tap(find.byKey(const Key('home-news-card')));
    await tester.pump();
    expect(opened, ShopAnnouncementSection.notices);

    opened = null;
    await tester.pumpWidget(
      _newsApp(
        setting: const HomeNewsSectionSetting(
          layout: HomeNewsLayouts.multiLine,
          source: HomeNewsSources.both,
          multiLineCount: 2,
        ),
        items: <HomeNewsItem>[
          _notice(id: 'n1', title: '店家公告標題'),
          _campaignItem(id: 'c1', title: '優惠活動標題'),
          _notice(id: 'n2', title: '第三筆不該出現'),
        ],
        phase: HomeNewsSectionPhase.ready,
        preview: false,
        onOpen: (ShopAnnouncementSection section) => opened = section,
      ),
    );
    expect(find.text('第三筆不該出現'), findsNothing);
    await tester.tap(find.byKey(const Key('home-news-item-c1')));
    await tester.pump();
    expect(opened, ShopAnnouncementSection.campaigns);
    await tester.tap(find.byKey(const Key('home-news-see-all')));
    await tester.pump();
    expect(opened, ShopAnnouncementSection.notices);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long titles and summaries stay inside the card', (
    WidgetTester tester,
  ) async {
    final String longText = '很長的消息標題與摘要' * 8;
    await tester.pumpWidget(
      _newsApp(
        width: 160,
        setting: const HomeNewsSectionSetting(
          layout: HomeNewsLayouts.multiLine,
          showSummary: true,
          showDate: true,
          showTypeBadge: true,
        ),
        items: <HomeNewsItem>[
          _notice(id: 'n1', title: longText, summary: longText),
          _campaignItem(id: 'c1', title: longText, summary: longText),
        ],
        phase: HomeNewsSectionPhase.ready,
        preview: true,
        onOpen: (_) {},
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('很長的消息標題'), findsWidgets);

    await tester.pumpWidget(
      _newsApp(
        width: 150,
        setting: const HomeNewsSectionSetting(
          layout: HomeNewsLayouts.compactCard,
        ),
        items: <HomeNewsItem>[_notice(id: 'n1', title: longText)],
        phase: HomeNewsSectionPhase.ready,
        preview: true,
        onOpen: (_) {},
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings controls follow the selected layout', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const _PanelHost(initial: HomeNewsSectionSetting(), locked: true),
    );
    expect(find.text(kHomeNewsLockedMessage), findsOneWidget);
    expect(find.text('版型'), findsNothing);
    expect(find.text('顯示摘要'), findsNothing);
    await tester.tap(find.byKey(const Key('home-news-open-features')));
    await tester.pump();
    expect(
      tester.state<_PanelHostState>(find.byType(_PanelHost)).featureOpens,
      1,
    );

    await _openDetails(
      tester,
      const HomeNewsSectionSetting(layout: HomeNewsLayouts.compactCard),
    );
    expect(find.text('內容來源'), findsOneWidget);
    expect(find.text('首頁標題'), findsOneWidget);
    expect(find.text('顯示摘要'), findsNothing);
    expect(find.text('顯示日期'), findsNothing);
    expect(find.text('顯示類型標籤'), findsNothing);
    expect(find.text('顯示箭頭'), findsNothing);
    expect(find.text('顯示查看全部'), findsNothing);
    expect(find.text('顯示數量'), findsNothing);

    await _openDetails(tester, const HomeNewsSectionSetting());
    expect(find.text('顯示箭頭'), findsOneWidget);
    expect(find.text('顯示數量'), findsNothing);
    expect(find.text('顯示摘要'), findsNothing);

    await _openDetails(
      tester,
      const HomeNewsSectionSetting(layout: HomeNewsLayouts.multiLine),
    );
    final _PanelHostState multi = tester.state<_PanelHostState>(
      find.byType(_PanelHost),
    );
    expect(find.text('顯示數量'), findsOneWidget);
    expect(find.text('顯示摘要'), findsOneWidget);
    expect(find.text('顯示日期'), findsOneWidget);
    expect(find.text('顯示類型標籤'), findsOneWidget);
    expect(find.text('顯示查看全部'), findsOneWidget);
    expect(find.text('顯示箭頭'), findsNothing);
    await tester.tap(find.text('2 筆'));
    await tester.pump();
    expect(multi.setting.multiLineCount, 2);
    await tester.tap(find.text('3 筆'));
    await tester.pump();
    expect(multi.setting.multiLineCount, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging announcements updates the draft order', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    try {
      final _NewsDragHost host = _NewsDragHost();
      await tester.pumpWidget(host);
      await tester.pump();
      final _NewsDragHostState state = tester.state<_NewsDragHostState>(
        find.byType(_NewsDragHost),
      );
      expect(find.byTooltip('拖曳整個最新消息區塊'), findsOneWidget);
      final Finder handle = find.byKey(
        const Key('home-section-drag-announcements'),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(handle),
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
      expect(state.selected, 'announcements');
      expect(state.order.first, 'announcements');
      expect(state.order, contains('rooms'));
      expect(state.order.toSet().length, state.order.length);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('preview and the live homepage share ModernHomeNewsSection', () {
    final String page = File(
      'lib/features/shop/pages/shop_public_modern_page.dart',
    ).readAsStringSync();
    expect(page.contains('ModernHomeNewsSection('), isTrue);
    expect(page.contains('_buildLatestAnnouncementSection'), isFalse);
    expect(page.contains('streamPublicCampaigns'), isTrue);
    expect(page.contains("modernAppearance['newsSection']"), isTrue);
    final String theme = File(
      'lib/features/shop/pages/shop_theme_setting_page.dart',
    ).readAsStringSync();
    expect(theme.contains("'newsSection': _newsSection.toMap()"), isTrue);
    expect(theme.contains('NewsSectionSettingsPanel'), isTrue);
  });
}

DiscountCampaignModel _campaign({
  required String id,
  required String name,
  required DateTime createdAt,
}) {
  return DiscountCampaignModel(
    id: id,
    shopId: 'shop',
    name: name,
    description: '活動說明',
    type: DiscountCampaignType.limitedTime,
    valueType: DiscountValueType.percent,
    applyTarget: DiscountApplyTarget.room,
    discountValue: 10,
    enabled: true,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

HomeNewsItem _notice({
  required String id,
  required String title,
  String summary = '摘要',
}) {
  return HomeNewsItem.notice(<String, dynamic>{
    'id': id,
    'title': title,
    'content': summary,
    'isPublished': true,
    'isPinned': false,
    'createdAt': DateTime(2026, 2, 2),
    'type': 'normal',
  });
}

HomeNewsItem _campaignItem({
  required String id,
  required String title,
  String summary = '活動說明',
}) {
  return HomeNewsItem.campaign(
    DiscountCampaignModel(
      id: id,
      shopId: 'shop',
      name: title,
      description: summary,
      type: DiscountCampaignType.limitedTime,
      valueType: DiscountValueType.percent,
      applyTarget: DiscountApplyTarget.room,
      discountValue: 10,
      enabled: true,
      createdAt: DateTime(2026, 3, 3),
      updatedAt: DateTime(2026, 3, 3),
    ),
  );
}

Widget _newsApp({
  required HomeNewsSectionSetting setting,
  required List<HomeNewsItem> items,
  required HomeNewsSectionPhase phase,
  required bool preview,
  required ValueChanged<ShopAnnouncementSection> onOpen,
  double width = 360,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: ModernHomeNewsSection(
            theme: HomeThemeModel.modernDefault,
            setting: setting,
            items: items,
            phase: phase,
            preview: preview,
            onOpen: onOpen,
          ),
        ),
      ),
    ),
  );
}

class _PanelHost extends StatefulWidget {
  const _PanelHost({required this.initial, this.locked = false});

  final HomeNewsSectionSetting initial;
  final bool locked;

  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> {
  late HomeNewsSectionSetting setting = widget.initial;
  int featureOpens = 0;

  @override
  void didUpdateWidget(_PanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    setting = widget.initial;
    featureOpens = 0;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 460,
          height: 1200,
          child: NewsSectionSettingsPanel(
            setting: setting,
            theme: HomeThemeModel.modernDefault,
            locked: widget.locked,
            onOpenFeatures: () {
              featureOpens += 1;
            },
            onChanged: (HomeNewsSectionSetting value) {
              setState(() => setting = value);
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _openDetails(
  WidgetTester tester,
  HomeNewsSectionSetting setting,
) async {
  await tester.pumpWidget(_PanelHost(initial: setting));
  await tester.pump();
  await tester.tap(find.text('顯示細節'));
  await tester.pump();
}

class _NewsDragHost extends StatefulWidget {
  const _NewsDragHost();

  @override
  State<_NewsDragHost> createState() => _NewsDragHostState();
}

class _NewsDragHostState extends State<_NewsDragHost> {
  List<String> order = <String>['rooms', 'announcements'];
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
            spanOf: (String sectionId) => HomeSectionSpan.half,
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
