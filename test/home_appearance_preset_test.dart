import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_appearance_preset.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_appearance_preset_strip.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_quick_booking_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('five presets keep shop content and only change layout', () {
    final HomeAppearanceDraft current = _shopDraft();
    expect(homeAppearancePresets, hasLength(5));
    expect(homeAppearancePresetById('missing'), isNull);
    expect(homeAppearancePresetStatus(presetId: null, draft: current), '尚未套用');

    for (final HomeAppearancePreset preset in homeAppearancePresets) {
      final HomeAppearanceDraft next = preset.apply(current);
      expect(preset.matches(next), isTrue, reason: preset.id);
      expect(preset.matches(preset.apply(next)), isTrue, reason: preset.id);
      _expectContentKept(current, next);
      expect(next.sectionOrder.toSet(), HomeSectionOrder.defaultOrder.toSet());
      expect(next.sectionOrder, next.sectionOrder.toSet().toList());
      expect(next.theme.primaryColorValue, current.theme.primaryColorValue);
      expect(next.theme.textColorValue, current.theme.textColorValue);
    }
  });

  test('navigation and quick booking follow each preset', () {
    final HomeAppearanceDraft current = _shopDraft();
    final HomeAppearanceDraft classic = _preset('classic').apply(current);
    final HomeAppearanceDraft minimal = _preset('minimal').apply(current);
    final HomeAppearanceDraft booking = _preset('booking').apply(current);
    final HomeAppearanceDraft brand = _preset('brand').apply(current);
    final HomeAppearanceDraft warm = _preset('warm').apply(current);

    expect(classic.navigation.style, FrontendNavigationConfig.styleBottom);
    expect(
      classic.navigation.bottomAppearance,
      FrontendNavigationConfig.appearanceAttached,
    );
    expect(minimal.navigation.style, FrontendNavigationConfig.styleDrawer);
    expect(brand.navigation.style, FrontendNavigationConfig.styleDrawer);
    expect(warm.navigation.style, FrontendNavigationConfig.styleBottom);
    expect(
      booking.navigation.bottomAppearance,
      FrontendNavigationConfig.appearanceFloatingPill,
    );

    expect(minimal.quickBooking.layout, HomeQuickBookingLayouts.spotlight);
    expect(minimal.quickBooking.showAccommodation, isFalse);
    expect(minimal.quickBooking.showDaycare, isTrue);
    expect(minimal.about.enabled, isTrue);
    expect(minimal.rooms.layout, HomeRoomSectionLayouts.simpleEntry);
    expect(minimal.news.showEmptyPlaceholder, isFalse);
    expect(minimal.showStayServiceStrip, isFalse);
    expect(minimal.sectionOrder.take(5), <String>[
      'banners',
      'quickBooking',
      'announcements',
      'facilities',
      'rooms',
    ]);
    expect(minimal.bannerFrame.heightPreset, HomeBannerHeightPreset.tall);

    expect(booking.quickBooking.layout, HomeQuickBookingLayouts.heroCta);
    expect(booking.quickBooking.showOnHome, isTrue);
    expect(booking.quickBooking.showAccommodation, isTrue);
    expect(booking.quickBooking.showDaycare, isTrue);
    expect(classic.information.faq.showOnHome, isTrue);
    expect(classic.information.policy.showOnHome, isTrue);
    expect(warm.environment.layout, HomeEnvironmentLayouts.editorial);
    expect(warm.sectionOrder.take(3), <String>[
      'banners',
      'about',
      'facilities',
    ]);
    expect(minimal.rooms.layout, HomeRoomSectionLayouts.simpleEntry);
    expect(
      minimal.featuredProductLayout,
      ModernFeaturedProductLayouts.featured,
    );
    expect(minimal.storeEntryLayout, ModernStoreEntryLayouts.brand);
    expect(
      minimal.sectionOrder.indexOf('storeEntrance'),
      greaterThan(minimal.sectionOrder.indexOf('faq')),
    );
    expect(brand.featuredProductLayout, ModernFeaturedProductLayouts.featured);
    expect(brand.storeEntryLayout, ModernStoreEntryLayouts.brand);
    expect(warm.featuredProductLayout, ModernFeaturedProductLayouts.grid);
    expect(
      classic.featuredProductLayout,
      ModernFeaturedProductLayouts.horizontal,
    );
    expect(classic.storeEntryLayout, ModernStoreEntryLayouts.banner);
    expect(
      booking.sectionOrder.indexOf('featured'),
      greaterThan(booking.sectionOrder.indexOf('rooms')),
    );
    expect(brand.rooms.layout, HomeRoomSectionLayouts.featured);
    expect(brand.environment.layout, HomeEnvironmentLayouts.imageEntry);
    expect(brand.about.layout, HomeAboutLayouts.brandIntro);
  });

  test(
    'a later edit keeps the preset name and does not reset other fields',
    () {
      final HomeAppearancePreset preset = _preset('minimal');
      final HomeAppearanceDraft applied = preset.apply(_shopDraft());
      final HomeAppearanceDraft edited = applied.copyWith(
        news: applied.news.copyWith(layout: HomeNewsLayouts.multiLine),
      );
      expect(preset.matches(edited), isFalse);
      expect(edited.navigation.style, FrontendNavigationConfig.styleDrawer);
      expect(edited.rooms.layout, HomeRoomSectionLayouts.simpleEntry);
      expect(edited.quickBooking.layout, HomeQuickBookingLayouts.spotlight);
      expect(
        homeAppearancePresetStatus(presetId: preset.id, draft: edited),
        '極簡品牌 · 已自訂',
      );
      expect(
        homeAppearancePresetStatus(presetId: preset.id, draft: applied),
        '極簡品牌',
      );
    },
  );

  test('empty content still applies', () {
    const HomeAppearanceDraft empty = HomeAppearanceDraft(
      theme: HomeThemeModel.modernDefault,
      sectionOrder: HomeSectionOrder.defaultOrder,
      rooms: HomeRoomSectionSetting(),
      environment: HomeEnvironmentSectionSetting(),
      about: HomeAboutSectionSetting(),
      news: HomeNewsSectionSetting(),
      quickBooking: HomeQuickBookingSectionSetting(),
      information: HomeInformationSectionsSetting(),
      navigation: FrontendNavigationConfig(
        style: FrontendNavigationConfig.styleDrawer,
        drawerItemOrder: <String>['booking', 'rooms'],
        drawerHiddenItemIds: <String>[],
        left1: 'booking',
        left2: 'rooms',
        right1: 'orders',
        right2: 'member',
        bottomAppearance: FrontendNavigationConfig.appearanceAttached,
        bottomSurface: FrontendNavigationConfig.surfaceOpaque,
      ),
      bannerFrame: ModernBannerFrameSetting(),
    );
    for (final HomeAppearancePreset preset in homeAppearancePresets) {
      expect(preset.apply(empty).about.imageUrl, isEmpty);
    }
  });

  testWidgets('booking preset does not invent a closed service door', (
    WidgetTester tester,
  ) async {
    final HomeAppearanceDraft booking = _preset('booking').apply(_shopDraft());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModernHomeQuickBookingSection(
            theme: booking.theme,
            setting: booking.quickBooking,
            accommodationAvailable: true,
            daycareAvailable: false,
            preview: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('home-quick-booking-stay')), findsOneWidget);
    expect(find.byKey(const Key('home-quick-booking-daycare')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModernHomeQuickBookingSection(
            theme: booking.theme,
            setting: booking.quickBooking,
            accommodationAvailable: false,
            daycareAvailable: true,
            preview: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('home-quick-booking-stay')), findsNothing);
    expect(find.byKey(const Key('home-quick-booking-daycare')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModernHomeQuickBookingSection(
            theme: booking.theme,
            setting: booking.quickBooking,
            accommodationAvailable: true,
            daycareAvailable: true,
            preview: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('home-quick-booking-stay')), findsOneWidget);
    expect(find.byKey(const Key('home-quick-booking-daycare')), findsOneWidget);
  });

  testWidgets('apply asks before changing the draft', (
    WidgetTester tester,
  ) async {
    HomeAppearancePreset? applied;
    HomeAppearancePreset? previewed;
    final HomeAppearanceDraft draft = _shopDraft();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeAppearancePresetStrip(
            draft: draft,
            presetId: null,
            accent: const Color(0xFF2255AA),
            onPreview: (HomeAppearancePreset preset) => previewed = preset,
            onApply: (HomeAppearancePreset preset) => applied = preset,
          ),
        ),
      ),
    );
    expect(find.text('快速套用前台風格'), findsOneWidget);
    expect(find.text('目前：尚未套用'), findsOneWidget);
    expect(find.text('極簡品牌'), findsOneWidget);
    expect(find.text('經典完整'), findsOneWidget);
    expect(find.text('預約優先'), findsOneWidget);

    await tester.tap(find.text('極簡品牌'));
    await tester.pumpAndSettle();
    expect(previewed?.id, 'minimal');
    expect(applied, isNull);

    await tester.tap(find.byKey(const Key('home-preset-apply-minimal')));
    await tester.pumpAndSettle();
    expect(find.text('套用「極簡品牌」？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(applied, isNull);

    await tester.tap(find.byKey(const Key('home-preset-apply-minimal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('套用模板'));
    await tester.pumpAndSettle();
    expect(applied?.id, 'minimal');
    final Finder carouselScroll = find.descendant(
      of: find.byKey(const Key('home-preset-carousel')),
      matching: find.byType(Scrollable),
    );
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    final ScrollableState carousel = tester.state(carouselScroll);
    expect(carousel.position.pixels, greaterThan(0));
    await tester.scrollUntilVisible(
      find.text('溫暖生活'),
      280,
      scrollable: carouselScroll,
    );
    expect(find.text('溫暖生活'), findsOneWidget);
  });
}

HomeAppearancePreset _preset(String id) {
  return homeAppearancePresetById(id)!;
}

HomeAppearanceDraft _shopDraft() {
  return HomeAppearanceDraft(
    theme: HomeThemeModel.modernDefault.copyWith(primaryColorValue: 0xFF2255AA),
    sectionOrder: HomeSectionOrder.defaultOrder,
    rooms: const HomeRoomSectionSetting(
      title: '豪華房',
      showPrice: false,
      roomTypeOrder: <String>['deluxe'],
      hiddenRoomTypeIds: <String>['closed'],
      mixed: HomeRoomMixedSetting(
        itemSizes: <String, String>{'deluxe': 'wide'},
      ),
    ),
    environment: const HomeEnvironmentSectionSetting(
      title: '我們的環境',
      subtitle: '保留說明',
    ),
    about: const HomeAboutSectionSetting(
      title: '關於毛孩',
      subtitle: '一段故事',
      imageUrl: 'https://example.com/about.jpg',
      buttonText: '看更多',
      useShopNameAsTitle: false,
    ),
    news: const HomeNewsSectionSetting(title: '店內消息', source: 'campaigns'),
    quickBooking: const HomeQuickBookingSectionSetting(
      title: '立刻訂',
      subtitle: '自訂說明',
      buttonText: '去預約',
      showAccommodation: false,
      showDaycare: true,
    ),
    information: const HomeInformationSectionsSetting(
      policy: HomePolicySectionSetting(
        title: '自訂須知',
        subtitle: '自訂規定',
        keepServiceEntry: false,
      ),
      faq: HomeFaqSectionSetting(title: '自訂問答', subtitle: '自訂問題'),
      reviews: HomeReviewSectionSetting(title: '自訂評價', subtitle: '自訂心聲'),
    ),
    navigation: FrontendNavigationConfig.defaults().copyWith(
      drawerHiddenItemIds: const <String>['faq'],
    ),
    bannerFrame: const ModernBannerFrameSetting(
      bannerImageFit: ModernBannerFrameSetting.fitContain,
    ),
  );
}

void _expectContentKept(HomeAppearanceDraft current, HomeAppearanceDraft next) {
  expect(next.rooms.title, current.rooms.title);
  expect(next.rooms.showPrice, current.rooms.showPrice);
  expect(next.rooms.roomTypeOrder, current.rooms.roomTypeOrder);
  expect(next.rooms.hiddenRoomTypeIds, current.rooms.hiddenRoomTypeIds);
  expect(next.rooms.mixed.itemSizes, current.rooms.mixed.itemSizes);
  expect(next.environment.title, current.environment.title);
  expect(next.environment.subtitle, current.environment.subtitle);
  expect(next.about.title, current.about.title);
  expect(next.about.subtitle, current.about.subtitle);
  expect(next.about.imageUrl, current.about.imageUrl);
  expect(next.about.buttonText, current.about.buttonText);
  expect(next.about.useShopNameAsTitle, current.about.useShopNameAsTitle);
  expect(next.news.title, current.news.title);
  expect(next.news.source, current.news.source);
  expect(next.quickBooking.title, current.quickBooking.title);
  expect(next.quickBooking.subtitle, current.quickBooking.subtitle);
  expect(next.quickBooking.buttonText, current.quickBooking.buttonText);
  expect(next.information.policy.title, current.information.policy.title);
  expect(next.information.policy.subtitle, current.information.policy.subtitle);
  expect(
    next.information.policy.keepServiceEntry,
    current.information.policy.keepServiceEntry,
  );
  expect(next.information.faq.title, current.information.faq.title);
  expect(next.information.reviews.title, current.information.reviews.title);
  expect(next.navigation.drawerItemOrder, current.navigation.drawerItemOrder);
  expect(
    next.navigation.drawerHiddenItemIds,
    current.navigation.drawerHiddenItemIds,
  );
  expect(next.navigation.left1, current.navigation.left1);
  expect(next.bannerFrame.bannerImageFit, current.bannerFrame.bannerImageFit);
}
