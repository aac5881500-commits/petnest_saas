import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_appearance_preset.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/home_storybook_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_storybook_surface.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_storybook_settings_panel.dart';

HomeAppearanceDraft fixture() => HomeAppearanceDraft(
  theme: HomeThemeModel.modernDefault,
  sectionOrder: const [],
  rooms: const HomeRoomSectionSetting(title: '我的房型'),
  environment: const HomeEnvironmentSectionSetting(title: '我的環境'),
  about: const HomeAboutSectionSetting(
    imageUrl: 'https://example.invalid/my-photo.jpg',
  ),
  news: const HomeNewsSectionSetting(),
  quickBooking: const HomeQuickBookingSectionSetting(showOnHome: false),
  information: const HomeInformationSectionsSetting(),
  navigation: FrontendNavigationConfig.defaults(),
  bannerFrame: const ModernBannerFrameSetting(),
  storeHome: const ModernStoreHomeSetting(
    storeBannerImageUrl: 'https://example.invalid/my-store.jpg',
    showFeaturedProducts: false,
    showStoreBanner: false,
  ),
);

void main() {
  test(
    'storybook keeps uploaded content and switches, includes all module positions',
    () {
      final original = fixture();
      final preset = homeAppearancePresetById('storybookCottage')!;
      final next = preset.apply(original);
      expect(next.theme.storybook.enabled, true);
      expect(next.theme.storybook.heroSource, 'shop');
      expect(next.theme.storybook.showShortcuts, false);
      expect(next.about.imageUrl, original.about.imageUrl);
      expect(next.rooms.title, original.rooms.title);
      expect(next.environment.title, original.environment.title);
      expect(
        next.storeHome.storeBannerImageUrl,
        original.storeHome.storeBannerImageUrl,
      );
      expect(next.storeHome.showFeaturedProducts, false);
      expect(next.storeHome.showStoreBanner, false);
      expect(next.quickBooking.showOnHome, false);
      expect(
        next.sectionOrder.toSet(),
        containsAll([
          'banners',
          'dailyCare',
          'rooms',
          'facilities',
          'announcements',
          'quickBooking',
          'featured',
          'storeEntrance',
          'services',
          'about',
          'policy',
          'faq',
          'reviews',
        ]),
      );
      expect(preset.matches(next), true);
      expect(
        homeAppearancePresetById(
          'creamOrange',
        )!.apply(next).theme.storybook.enabled,
        false,
      );
    },
  );

  test('all custom visual settings survive theme save/read/copy', () {
    final story = const HomeStorybookSetting(enabled: true).copyWith(
      heroTitle: '我自己的首頁',
      heroSource: 'shop',
      heroAlign: 'center',
      paperColor: 0xFFFFDDEE,
      blueColor: 0xFFCCDDEE,
      radius: 17,
      decorationOpacity: .3,
      gap: 20,
      decorateSections: ['rooms'],
      blueSections: ['rooms'],
    );
    final before = HomeThemeModel.modernDefault.copyWith(storybook: story);
    final loaded = HomeThemeModel.fromMap(
      before.toMap(),
      fallback: HomeThemeModel.modernDefault,
    );
    expect(loaded.storybook.toMap(), story.toMap());
    expect(
      loaded.copyWith(primaryColorValue: 0xFF123456).storybook.toMap(),
      story.toMap(),
    );
  });

  test(
    'first-version saved preset restores shop cover and hides extra shortcuts',
    () {
      final migrated = HomeStorybookSetting.fromMap({
        'enabled': true,
        'heroSource': 'builtin',
        'showShortcuts': true,
        'paperColor': 0xFFFFDDEE,
      });
      expect(migrated.heroSource, 'shop');
      expect(migrated.showShortcuts, false);
      expect(migrated.paperColor, 0xFFFFDDEE);
      final custom = migrated.copyWith(
        heroSource: 'builtin',
        showShortcuts: true,
      );
      expect(
        HomeStorybookSetting.fromMap(custom.toMap()).heroSource,
        'builtin',
      );
      expect(HomeStorybookSetting.fromMap(custom.toMap()).showShortcuts, true);
    },
  );
  test('legacy data remains plain and malformed dimensions are bounded', () {
    expect(
      HomeThemeModel.fromMap(
        {},
        fallback: HomeThemeModel.modernDefault,
      ).storybook.enabled,
      false,
    );
    final bad = HomeStorybookSetting.fromMap({
      'radius': -10,
      'gap': 999,
      'paperColor': -1,
      'heroAspect': double.nan,
      'decorateSections': [4, 'rooms', 'rooms'],
    });
    expect(bad.radius, 0);
    expect(bad.gap, 32);
    expect(bad.heroAspect, 2.4);
    expect(bad.decorateSections, ['rooms']);
  });

  testWidgets('hidden modules have no decorative blank cards', (tester) async {
    const key = Key('empty');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeStorybookSurface(
            key: key,
            sectionId: 'rooms',
            setting: HomeStorybookSetting(enabled: true),
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(key)).height, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow large text hero and shortcuts remain usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  HomeStorybookHero(
                    setting: const HomeStorybookSetting(enabled: true),
                    theme: HomeThemeModel.modernDefault,
                    onBook: () => opened = true,
                  ),
                  HomeStorybookShortcuts(
                    setting: const HomeStorybookSetting(enabled: true),
                    theme: HomeThemeModel.modernDefault,
                    items: const [
                      (id: 'booking', label: '預約', icon: Icons.calendar_month),
                      (id: 'rooms', label: '房型', icon: Icons.bed),
                      (id: 'policy', label: '須知', icon: Icons.article),
                      (id: 'member', label: '會員', icon: Icons.person),
                    ],
                    onOpen: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('預約住宿'));
    expect(opened, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings edit title, image source and dimensions through controls',
    (tester) async {
      var story = const HomeStorybookSetting(enabled: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => HomeStorybookSettingsPanel(
                  setting: story,
                  onChanged: (next) => setState(() => story = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('可選內建插畫'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '主圖標題'),
        '我的水彩旅店',
      );
      await tester.pump();
      expect(story.heroTitle, '我的水彩旅店');
      await tester.tap(find.text('店家上傳海報'));
      await tester.pumpAndSettle();
      expect(story.heroSource, 'shop');
      final slider = find.byType(Slider).first;
      await tester.ensureVisible(slider);
      await tester.tap(slider);
      await tester.pump();
      final loaded = HomeStorybookSetting.fromMap(story.toMap());
      expect(loaded.toMap(), story.toMap());
      expect(tester.takeException(), isNull);
    },
  );
}
