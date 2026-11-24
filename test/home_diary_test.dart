import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_appearance_preset.dart';
import 'package:petnest_saas/core/models/home_diary_setting.dart';
import 'package:petnest_saas/core/models/home_storybook_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_diary_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_diary_settings_panel.dart';
import 'home_storybook_test.dart' show fixture;

const openShop = FrontendNavShopState(
  paidPlan: true,
  storeEnabled: true,
  chatEnabled: true,
  announcementsEnabled: true,
  faqEnabled: true,
  showMemberCenter: true,
  showShopMenus: true,
  loggedIn: true,
);

void main() {
  final preset = homeAppearancePresetById('catDiary')!;
  final draft = preset.apply(fixture());
  final theme = draft.theme;
  final diary = theme.storybook.diary;

  test(
    'C preset retains shop content and exposes repeatable editable settings',
    () {
      final original = fixture();
      expect(preset.matches(draft), true);
      expect(diary.enabled, true);
      expect(theme.storybook.heroSource, 'shop');
      expect(theme.storybook.showShortcuts, false);
      expect(draft.about.imageUrl, original.about.imageUrl);
      expect(
        draft.storeHome.storeBannerImageUrl,
        original.storeHome.storeBannerImageUrl,
      );
      expect(
        draft.storeHome.showStoreBanner,
        original.storeHome.showStoreBanner,
      );
      expect(draft.environment.layout, HomeEnvironmentLayouts.diaryRows);
      expect(draft.sectionOrder.take(5), [
        'banners',
        'dailyCare',
        'announcements',
        'facilities',
        'rooms',
      ]);
      expect(
        draft.navigation.resolvedBottomSlots(openShop).map((item) => item?.id),
        ['home', 'rooms', 'booking', 'orders', 'member'],
      );
      final restored = HomeThemeModel.fromMap(
        theme.toMap(),
        fallback: HomeThemeModel.modernDefault,
      );
      expect(restored.storybook.diary.toMap(), diary.toMap());
      expect(
        homeAppearancePresetById(
          'storybookCottage',
        )!.apply(draft).theme.storybook.diary.enabled,
        false,
      );
    },
  );

  test(
    'all diary controls round-trip and malformed dimensions stay bounded',
    () {
      final changed = diary.copyWith(
        coverTitle: '我的封面標題',
        coverPhotoSide: 'left',
        coverPhotoSource: 'banner',
        showTimeline: false,
        lineColor: 0xFFAABBCC,
        lineWidth: 2.5,
        headingSize: 21,
        coverPhotoFraction: .6,
        coverPhotoAspect: 1.4,
        groupPreparation: false,
        groupStore: false,
        compactCare: false,
        titles: {'rooms': '我的日記房型'},
        surfaces: {'rooms': 'paper'},
        timelineSections: ['rooms'],
        showTape: false,
        alternatePhotos: false,
      );
      final saved = theme
          .copyWith(storybook: theme.storybook.copyWith(diary: changed))
          .toMap();
      expect(
        HomeThemeModel.fromMap(
          saved,
          fallback: HomeThemeModel.modernDefault,
        ).storybook.diary.toMap(),
        changed.toMap(),
      );
      final bad = HomeDiarySetting.fromMap({
        'gutter': -20,
        'coverPhotoFraction': 99,
        'headingSize': double.nan,
        'timelineSections': ['rooms', 'rooms', 4, 'unknown'],
        'lineColor': -1,
      });
      expect(bad.gutter, 20);
      expect(bad.coverPhotoFraction, .7);
      expect(bad.headingSize, 16);
      expect(bad.timelineSections, ['rooms']);
      expect(HomeStorybookSetting.fromMap({'version': 2}).diary.enabled, false);
    },
  );

  test(
    'central booking persists and unavailable booking falls back safely',
    () {
      final config = draft.navigation;
      expect(FrontendNavigationConfig.fromMap(config.toMap()), config);
      expect(config.copyWith(centerId: 'home') == config, false);
      final closed = FrontendNavShopState(
        paidPlan: false,
        storeEnabled: false,
        chatEnabled: false,
        announcementsEnabled: false,
        faqEnabled: false,
        showMemberCenter: true,
        showShopMenus: true,
        loggedIn: false,
      );
      final ids = config
          .resolvedBottomSlots(closed)
          .map((item) => item?.id)
          .toList();
      expect(ids[2], 'home');
      expect(ids.where((id) => id == 'home'), hasLength(1));
      expect(ids, isNot(contains('booking')));
      expect(FrontendNavigationConfig.fromMap({}).centerId, 'home');
    },
  );

  test('platform paper and tape are bundled assets', () async {
    expect(
      (await rootBundle.load(HomeDiarySetting.paperAsset)).lengthInBytes,
      greaterThan(100),
    );
    expect(
      (await rootBundle.load(HomeDiarySetting.tapeAsset)).lengthInBytes,
      greaterThan(100),
    );
  });

  testWidgets('empty diary chapters collapse their title, paper and rail', (
    tester,
  ) async {
    const key = Key('chapter');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeDiaryChapter(
            key: key,
            sectionId: 'rooms',
            setting: diary,
            theme: theme,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(key)).height, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chapter content remains tappable at shifted offset', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeDiaryChapter(
            sectionId: 'rooms',
            setting: diary,
            theme: theme,
            child: SizedBox(
              height: 60,
              child: TextButton(
                onPressed: () => opened = true,
                child: const Text('查看房型'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看房型'));
    expect(opened, true);
    expect(find.text(diary.titles['rooms']!), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cover, alternating photos and compact care fit narrow large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    HomeDiaryCover(setting: diary, theme: theme, imageUrl: ''),
                    HomeDiaryCareRibbon(
                      petNames: '很長的貓咪名字與另一隻貓咪',
                      progressText: '今日 1／3 場已更新',
                      theme: theme,
                      onOpen: () {},
                      count: 3,
                      completed: const {0},
                      ready: true,
                    ),
                    HomeDiaryEnvironmentRows(
                      items: const [
                        {'title': '窗邊小窩', 'description': '這是店家自己填寫的介紹'},
                        {'title': '自在攀爬', 'description': '這也是店家自己填寫的介紹'},
                      ],
                      theme: theme,
                      onOpen: () {},
                    ),
                    HomeDiaryPreparation(
                      policy: const Text('入住須知'),
                      faq: const Text('常見問題'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('C controls edit and restore cover, chapter title and rail', (
    tester,
  ) async {
    var setting = diary;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => HomeDiarySettingsPanel(
                setting: setting,
                onChanged: (value) => setState(() => setting = value),
                onOpenPhotos: () {},
                onOpenEnvironment: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '封面主標題'),
      '我的貓咪日記',
    );
    await tester.pump();
    expect(setting.coverTitle, '我的貓咪日記');
    await tester.ensureVisible(find.text('時間軸、爪印與平台裝飾'));
    await tester.tap(find.text('時間軸、爪印與平台裝飾'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('顯示時間軸線'));
    await tester.tap(find.text('顯示時間軸線'));
    await tester.pumpAndSettle();
    expect(setting.showTimeline, false);
    final saved = HomeDiarySetting.fromMap(setting.toMap());
    expect(saved.toMap(), setting.toMap());
    expect(tester.takeException(), isNull);
  });
}
