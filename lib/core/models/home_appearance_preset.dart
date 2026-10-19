// 檔案名稱：lib/core/models/home_appearance_preset.dart
// 功能說明：新版前台外觀的快速模板。只改排版與視覺，不改店家內容。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_quick_action_setting.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_shared_entry_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';

/// 模板可以改的外觀草稿。店名、Logo、海報圖與各區塊內文不在這裡。
class HomeAppearanceDraft {
  const HomeAppearanceDraft({
    required this.theme,
    required this.sectionOrder,
    required this.rooms,
    required this.environment,
    required this.about,
    required this.news,
    required this.quickBooking,
    required this.information,
    required this.navigation,
    required this.bannerFrame,
    this.sharedEntry = const HomeSharedEntrySectionSetting(),
    this.displayStyle = HomeDisplayStyleSetting.unset,
    this.bannerButtonColorValue = 0xFF8B6548,
    this.bannerButtonTextColorValue = 0xFFFFFFFF,
    this.brandStyle = const StoreBrandStyle(),
    this.quickActions = const HomeQuickActionSetting(),
    this.showStayServiceStrip = true,
    this.featuredProductLayout = ModernFeaturedProductLayouts.horizontal,
    this.storeEntryLayout = ModernStoreEntryLayouts.banner,
  });

  final HomeThemeModel theme;
  final List<String> sectionOrder;
  final HomeRoomSectionSetting rooms;
  final HomeEnvironmentSectionSetting environment;
  final HomeAboutSectionSetting about;
  final HomeNewsSectionSetting news;
  final HomeQuickBookingSectionSetting quickBooking;
  final HomeInformationSectionsSetting information;
  final FrontendNavigationConfig navigation;
  final ModernBannerFrameSetting bannerFrame;
  final HomeSharedEntrySectionSetting sharedEntry;
  final HomeDisplayStyleSetting displayStyle;
  final StoreBrandStyle brandStyle;
  final HomeQuickActionSetting quickActions;
  final int bannerButtonColorValue;
  final int bannerButtonTextColorValue;
  final bool showStayServiceStrip;
  final String featuredProductLayout;
  final String storeEntryLayout;

  HomeAppearanceDraft copyWith({
    HomeThemeModel? theme,
    List<String>? sectionOrder,
    HomeRoomSectionSetting? rooms,
    HomeEnvironmentSectionSetting? environment,
    HomeAboutSectionSetting? about,
    HomeNewsSectionSetting? news,
    HomeQuickBookingSectionSetting? quickBooking,
    HomeInformationSectionsSetting? information,
    FrontendNavigationConfig? navigation,
    ModernBannerFrameSetting? bannerFrame,
    HomeSharedEntrySectionSetting? sharedEntry,
    HomeDisplayStyleSetting? displayStyle,
    StoreBrandStyle? brandStyle,
    HomeQuickActionSetting? quickActions,
    bool? showStayServiceStrip,
    String? featuredProductLayout,
    String? storeEntryLayout,
    int? bannerButtonColorValue,
    int? bannerButtonTextColorValue,
  }) {
    return HomeAppearanceDraft(
      theme: theme ?? this.theme,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      rooms: rooms ?? this.rooms,
      environment: environment ?? this.environment,
      about: about ?? this.about,
      news: news ?? this.news,
      quickBooking: quickBooking ?? this.quickBooking,
      information: information ?? this.information,
      navigation: navigation ?? this.navigation,
      bannerFrame: bannerFrame ?? this.bannerFrame,
      sharedEntry: sharedEntry ?? this.sharedEntry,
      displayStyle: displayStyle ?? this.displayStyle,
      brandStyle: brandStyle ?? this.brandStyle,
      quickActions: quickActions ?? this.quickActions,
      bannerButtonColorValue:
          bannerButtonColorValue ?? this.bannerButtonColorValue,
      bannerButtonTextColorValue:
          bannerButtonTextColorValue ?? this.bannerButtonTextColorValue,
      showStayServiceStrip: showStayServiceStrip ?? this.showStayServiceStrip,
      featuredProductLayout:
          featuredProductLayout ?? this.featuredProductLayout,
      storeEntryLayout: storeEntryLayout ?? this.storeEntryLayout,
    );
  }
}

class HomeAppearancePreset {
  const HomeAppearancePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.navigationLabel,
    required this.apply,
  });

  final String id;
  final String name;
  final String description;
  final String navigationLabel;
  final HomeAppearanceDraft Function(HomeAppearanceDraft current) apply;

  /// 目前草稿的排版與樣式，是否仍等於這套模板套用後的結果。
  bool matches(HomeAppearanceDraft current) {
    return homeAppearanceDraftSignature(apply(current)) ==
        homeAppearanceDraftSignature(current);
  }
}

const String homeAppearancePresetIdKey = 'appearancePresetId';

const List<HomeAppearancePreset> homeAppearancePresets = <HomeAppearancePreset>[
  HomeAppearancePreset(
    id: 'classic',
    name: '經典完整',
    description: '資訊完整，主內容、次要資訊與工具入口分開。',
    navigationLabel: '底部選單',
    apply: _applyClassic,
  ),
  HomeAppearancePreset(
    id: 'minimal',
    name: '奶油極簡',
    description: '奶油白留白、精簡入口與左側選單。',
    navigationLabel: '左側導覽',
    apply: _applyMinimal,
  ),
  HomeAppearancePreset(
    id: 'booking',
    name: '預約優先',
    description: '進站就看到住宿與安親兩張大按鈕。',
    navigationLabel: '底部懸浮選單',
    apply: _applyBooking,
  ),
  HomeAppearancePreset(
    id: 'brand',
    name: '精品旅宿',
    description: '超大房型圖片，像精品旅館官網。',
    navigationLabel: '左側導覽',
    apply: _applyBrand,
  ),
  HomeAppearancePreset(
    id: 'warm',
    name: '溫暖日常',
    description: '米杏底色、柔和綠意與圖文交錯。',
    navigationLabel: '底部選單',
    apply: _applyWarm,
  ),
];

HomeAppearancePreset? homeAppearancePresetById(String? id) {
  final String key = id?.trim() ?? '';
  if (key.isEmpty) {
    return null;
  }
  for (final HomeAppearancePreset preset in homeAppearancePresets) {
    if (preset.id == key) {
      return preset;
    }
  }
  return null;
}

/// 尚未套用時回傳「尚未套用」。改過模板後仍保留來源名稱。
String homeAppearancePresetStatus({
  required String? presetId,
  required HomeAppearanceDraft draft,
}) {
  final HomeAppearancePreset? preset = homeAppearancePresetById(presetId);
  if (preset == null) {
    return '尚未套用';
  }
  if (preset.matches(draft)) {
    return preset.name;
  }
  return '${preset.name} · 已自訂';
}

String homeAppearanceDraftSignature(HomeAppearanceDraft draft) {
  return jsonEncode(<String, Object?>{
    'theme': draft.theme.toMap(),
    'order': draft.sectionOrder,
    'rooms': draft.rooms.toMap(),
    'environment': draft.environment.toMap(),
    'about': draft.about.toMap(),
    'news': draft.news.toMap(),
    'quickBooking': draft.quickBooking.toMap(),
    'information': draft.information.toMap(),
    'navigation': draft.navigation.toMap(),
    'bannerFrame': draft.bannerFrame.toMap(),
    'sharedEntry': draft.sharedEntry.toMap(),
    'displayStyle': draft.displayStyle.saved
        ? draft.displayStyle.toMap()
        : <String, Object?>{'saved': false},
    'brandStyle': draft.brandStyle.toMap(),
    'quickActions': draft.quickActions.toMap(),
    'showStayServiceStrip': draft.showStayServiceStrip,
    'featuredProductLayout': draft.featuredProductLayout,
    'storeEntryLayout': draft.storeEntryLayout,
    'bannerButtonColor': draft.bannerButtonColorValue,
    'bannerButtonTextColor': draft.bannerButtonTextColorValue,
  });
}

HomeAppearanceDraft _applyClassic(HomeAppearanceDraft current) {
  return _paint(
    current,
    front: const <String>[
      'banners',
      'quickBooking',
      'rooms',
      'announcements',
      'facilities',
      'policy',
      'faq',
      'about',
      'reviews',
      'featured',
      'storeEntrance',
    ],
    theme: (HomeThemeModel theme) => _surfaces(
      theme,
      background: 0xFFFFFBF7,
      card: 0xFFFFFFFF,
      border: 0xFFFFD9B3,
    ),
    rooms: _scrollRooms,
    environment: (HomeEnvironmentSectionSetting environment) => _environment(
      environment,
      layout: HomeEnvironmentLayouts.facilityScroll,
    ),
    about: (HomeAboutSectionSetting about) => _about(
      about,
      enabled: true,
      layout: HomeAboutLayouts.simpleEntry,
      cardSize: HomeAboutCardSizes.standard,
      surface: HomeAboutSurfaces.solid,
    ),
    news: (HomeNewsSectionSetting news) => _news(
      news,
      layout: HomeNewsLayouts.multiLine,
      surface: HomeNewsSurfaces.solid,
      showSummary: true,
    ),
    quickBooking: (HomeQuickBookingSectionSetting booking) => _booking(
      booking,
      layout: HomeQuickBookingLayouts.serviceSplit,
      surface: HomeQuickBookingSurfaces.solid,
    ),
    information: (HomeInformationSectionsSetting information) => _information(
      information,
      policy: true,
      policyLayout: HomePolicyLayouts.summary,
      faq: true,
      faqLayout: HomeFaqLayouts.preview,
      reviews: true,
      reviewLayout: HomeReviewLayouts.carousel,
    ),
    navigation: _bottomAttached,
    bannerWidth: HomeBannerWidthPreset.standard,
    bannerHeight: HomeBannerHeightPreset.standard,
    featuredProductLayout: ModernFeaturedProductLayouts.horizontal,
    storeEntryLayout: ModernStoreEntryLayouts.banner,
  );
}

HomeAppearanceDraft _applyMinimal(HomeAppearanceDraft current) {
  return _paint(
    current,
    front: const <String>[
      'banners',
      'quickBooking',
      'sharedEntries',
      'announcements',
      'facilities',
      'rooms',
      'policy',
      'about',
      'reviews',
      'faq',
      'storeEntrance',
      'featured',
    ],
    theme: (HomeThemeModel theme) => _theme(
      theme,
      background: 0xFFFAF7F2,
      card: 0xFFFFFFFF,
      border: 0xFFE9E1D7,
      primary: 0xFF8B6548,
      text: 0xFF342D28,
      secondary: 0xFF756B62,
      button: 0xFF8B6548,
    ),
    rooms: _entryRooms,
    environment: (HomeEnvironmentSectionSetting environment) => _environment(
      environment,
      layout: HomeEnvironmentLayouts.simpleEntry,
      cardSize: HomeEnvironmentCardSizes.small,
    ),
    about: (HomeAboutSectionSetting about) => _about(
      about,
      enabled: true,
      layout: HomeAboutLayouts.simpleEntry,
      cardSize: HomeAboutCardSizes.small,
      surface: HomeAboutSurfaces.solid,
    ),
    news: (HomeNewsSectionSetting news) => _news(
      news,
      layout: HomeNewsLayouts.singleLine,
      surface: HomeNewsSurfaces.translucent,
      showSummary: false,
      showEmpty: false,
    ),
    quickBooking: (HomeQuickBookingSectionSetting booking) => _booking(
      booking,
      layout: HomeQuickBookingLayouts.spotlight,
      surface: HomeQuickBookingSurfaces.solid,
    ),
    information: (HomeInformationSectionsSetting information) => _information(
      information,
      policy: true,
      policyLayout: HomePolicyLayouts.compact,
      faq: true,
      faqLayout: HomeFaqLayouts.preview,
      reviews: true,
      reviewLayout: HomeReviewLayouts.carousel,
    ),
    navigation: _drawer,
    brandStyle: (StoreBrandStyle style) => _brand(
      style,
      nameColor: 0xFF342D28,
      subtitleColor: 0xFF756B62,
      headerBackground: 0xFFFFFFFF,
    ),
    quickActions: (HomeQuickActionSetting setting) =>
        _quickActions(setting, background: 0xFFFFFFFF, icon: 0xFF8B6548),
    sharedEntry: (HomeSharedEntrySectionSetting setting) => _sharedEntries(
      setting,
      columns: 3,
      aspect: 'landscape',
      radius: 'small',
      imageScale: 0.82,
      gapX: 12,
      gapY: 12,
      cardOrder: const <String>[
        HomeSharedEntrySources.rooms,
        HomeSharedEntrySources.facilities,
        HomeSharedEntrySources.about,
        HomeSharedEntrySources.announcements,
        HomeSharedEntrySources.reviews,
        HomeSharedEntrySources.policy,
        HomeSharedEntrySources.faq,
        HomeSharedEntrySources.quickBooking,
      ],
    ),
    displayStyle: (HomeDisplayStyleSetting setting) => _displayStyle(
      text: 0xFF342D28,
      secondary: 0xFF756B62,
      spacing: HomeDisplaySpacings.compact,
      radius: HomeDisplayRadii.small,
      aspect: 'landscape',
    ),
    bannerButtonColorValue: 0xFF8B6548,
    bannerButtonTextColorValue: 0xFFFFFFFF,
    bannerWidth: HomeBannerWidthPreset.full,
    bannerHeight: HomeBannerHeightPreset.tall,
    showStayServiceStrip: false,
    featuredProductLayout: ModernFeaturedProductLayouts.featured,
    storeEntryLayout: ModernStoreEntryLayouts.brand,
  );
}

HomeAppearanceDraft _applyBooking(HomeAppearanceDraft current) {
  return _paint(
    current,
    front: const <String>[
      'banners',
      'quickBooking',
      'rooms',
      'announcements',
      'reviews',
      'facilities',
      'featured',
      'storeEntrance',
    ],
    theme: (HomeThemeModel theme) => _surfaces(
      theme,
      background: 0xFFFFF8F4,
      card: 0xFFFFFFFF,
      borderAlpha: 0.20,
    ),
    rooms: _scrollRooms,
    environment: (HomeEnvironmentSectionSetting environment) =>
        _environment(environment, layout: HomeEnvironmentLayouts.imageEntry),
    about: (HomeAboutSectionSetting about) => _about(
      about,
      enabled: false,
      layout: about.layout,
      cardSize: about.cardSize,
      surface: about.surfaceStyle,
    ),
    news: (HomeNewsSectionSetting news) => _news(
      news,
      layout: HomeNewsLayouts.multiLine,
      surface: HomeNewsSurfaces.solid,
      showSummary: true,
    ),
    quickBooking: (HomeQuickBookingSectionSetting booking) => _booking(
      booking,
      layout: HomeQuickBookingLayouts.heroCta,
      surface: HomeQuickBookingSurfaces.solid,
    ),
    information: (HomeInformationSectionsSetting information) => _information(
      information,
      policy: false,
      policyLayout: information.policy.layout,
      faq: false,
      faqLayout: information.faq.layout,
      reviews: true,
      reviewLayout: HomeReviewLayouts.featured,
    ),
    navigation: _bottomFloating,
    showStayServiceStrip: false,
    bannerWidth: HomeBannerWidthPreset.full,
    bannerHeight: HomeBannerHeightPreset.standard,
    featuredProductLayout: ModernFeaturedProductLayouts.horizontal,
    storeEntryLayout: ModernStoreEntryLayouts.banner,
  );
}

HomeAppearanceDraft _applyBrand(HomeAppearanceDraft current) {
  return _paint(
    current,
    front: const <String>[
      'banners',
      'quickBooking',
      'rooms',
      'facilities',
      'sharedEntries',
      'about',
      'reviews',
      'featured',
      'storeEntrance',
    ],
    theme: (HomeThemeModel theme) => _theme(
      theme,
      background: 0xFFF5F3EF,
      card: 0xFFFFFEFC,
      border: 0xFFE7E1D8,
      primary: 0xFF735B48,
      text: 0xFF38322D,
      secondary: 0xFF77716A,
      button: 0xFF735B48,
    ),
    rooms: _featuredRooms,
    environment: (HomeEnvironmentSectionSetting environment) => _environment(
      environment,
      layout: HomeEnvironmentLayouts.imageEntry,
      imageHeight: HomeEnvironmentImageHeights.tall,
    ),
    about: (HomeAboutSectionSetting about) => _about(
      about,
      enabled: true,
      layout: HomeAboutLayouts.brandIntro,
      cardSize: HomeAboutCardSizes.wide,
      surface: HomeAboutSurfaces.translucent,
      showImage: true,
    ),
    news: (HomeNewsSectionSetting news) => _news(
      news,
      layout: HomeNewsLayouts.singleLine,
      surface: HomeNewsSurfaces.translucent,
      showSummary: false,
      showEmpty: false,
    ),
    quickBooking: (HomeQuickBookingSectionSetting booking) => _booking(
      booking,
      layout: HomeQuickBookingLayouts.singleLine,
      surface: HomeQuickBookingSurfaces.translucent,
    ),
    information: (HomeInformationSectionsSetting information) => _information(
      information,
      policy: false,
      policyLayout: HomePolicyLayouts.compact,
      faq: false,
      faqLayout: HomeFaqLayouts.compact,
      reviews: true,
      reviewLayout: HomeReviewLayouts.carousel,
    ),
    navigation: _drawer,
    brandStyle: (StoreBrandStyle style) => _brand(
      style,
      nameColor: 0xFF38322D,
      subtitleColor: 0xFF77716A,
      headerBackground: 0xFFFFFEFC,
    ),
    quickActions: (HomeQuickActionSetting setting) =>
        _quickActions(setting, background: 0xFFFFFEFC, icon: 0xFF735B48),
    sharedEntry: (HomeSharedEntrySectionSetting setting) => _sharedEntries(
      setting,
      columns: 2,
      aspect: 'portrait',
      radius: 'small',
      imageScale: 0.92,
      gapX: 18,
      gapY: 20,
      cardOrder: const <String>[
        HomeSharedEntrySources.rooms,
        HomeSharedEntrySources.facilities,
        HomeSharedEntrySources.about,
        HomeSharedEntrySources.announcements,
        HomeSharedEntrySources.reviews,
        HomeSharedEntrySources.policy,
        HomeSharedEntrySources.faq,
        HomeSharedEntrySources.quickBooking,
      ],
    ),
    displayStyle: (HomeDisplayStyleSetting setting) => _displayStyle(
      text: 0xFF38322D,
      secondary: 0xFF77716A,
      spacing: HomeDisplaySpacings.relaxed,
      radius: HomeDisplayRadii.small,
      aspect: 'portrait',
    ),
    bannerButtonColorValue: 0xFF735B48,
    bannerButtonTextColorValue: 0xFFFFFFFF,
    bannerWidth: HomeBannerWidthPreset.full,
    bannerHeight: HomeBannerHeightPreset.tall,
    showStayServiceStrip: false,
    featuredProductLayout: ModernFeaturedProductLayouts.featured,
    storeEntryLayout: ModernStoreEntryLayouts.brand,
  );
}

HomeAppearanceDraft _applyWarm(HomeAppearanceDraft current) {
  return _paint(
    current,
    front: const <String>[
      'banners',
      'quickBooking',
      'about',
      'facilities',
      'rooms',
      'sharedEntries',
      'reviews',
      'featured',
      'announcements',
      'storeEntrance',
    ],
    theme: (HomeThemeModel theme) => _theme(
      theme,
      background: 0xFFF5EFE5,
      card: 0xFFFFFBF5,
      border: 0xFFE7DDD0,
      primary: 0xFF5A765F,
      text: 0xFF3B362F,
      secondary: 0xFF777368,
      button: 0xFF5A765F,
    ),
    rooms: _featuredRooms,
    environment: (HomeEnvironmentSectionSetting environment) =>
        _environment(environment, layout: HomeEnvironmentLayouts.editorial),
    about: (HomeAboutSectionSetting about) => _about(
      about,
      enabled: true,
      layout: HomeAboutLayouts.imageEntry,
      cardSize: HomeAboutCardSizes.wide,
      surface: HomeAboutSurfaces.translucent,
      showImage: true,
    ),
    news: (HomeNewsSectionSetting news) => _news(
      news,
      layout: HomeNewsLayouts.multiLine,
      surface: HomeNewsSurfaces.solid,
      showSummary: true,
    ),
    quickBooking: (HomeQuickBookingSectionSetting booking) => _booking(
      booking,
      layout: HomeQuickBookingLayouts.singleLine,
      surface: HomeQuickBookingSurfaces.solid,
    ),
    information: (HomeInformationSectionsSetting information) => _information(
      information,
      policy: false,
      policyLayout: HomePolicyLayouts.compact,
      faq: false,
      faqLayout: HomeFaqLayouts.compact,
      reviews: true,
      reviewLayout: HomeReviewLayouts.carousel,
    ),
    navigation: _bottomAttached,
    brandStyle: (StoreBrandStyle style) => _brand(
      style,
      nameColor: 0xFF3B362F,
      subtitleColor: 0xFF777368,
      headerBackground: 0xFFFFFBF5,
    ),
    quickActions: (HomeQuickActionSetting setting) =>
        _quickActions(setting, background: 0xFFFFFBF5, icon: 0xFF5A765F),
    sharedEntry: (HomeSharedEntrySectionSetting setting) => _sharedEntries(
      setting,
      columns: 2,
      aspect: 'square',
      radius: 'medium',
      imageScale: 0.88,
      gapX: 14,
      gapY: 16,
      cardOrder: const <String>[
        HomeSharedEntrySources.facilities,
        HomeSharedEntrySources.about,
        HomeSharedEntrySources.rooms,
        HomeSharedEntrySources.announcements,
        HomeSharedEntrySources.reviews,
        HomeSharedEntrySources.policy,
        HomeSharedEntrySources.faq,
        HomeSharedEntrySources.quickBooking,
      ],
    ),
    displayStyle: (HomeDisplayStyleSetting setting) => _displayStyle(
      text: 0xFF3B362F,
      secondary: 0xFF777368,
      spacing: HomeDisplaySpacings.normal,
      radius: HomeDisplayRadii.medium,
      aspect: 'square',
    ),
    bannerButtonColorValue: 0xFF5A765F,
    bannerButtonTextColorValue: 0xFFFFFFFF,
    bannerWidth: HomeBannerWidthPreset.full,
    bannerHeight: HomeBannerHeightPreset.standard,
    showStayServiceStrip: false,
    featuredProductLayout: ModernFeaturedProductLayouts.grid,
    storeEntryLayout: ModernStoreEntryLayouts.brand,
  );
}

HomeAppearanceDraft _paint(
  HomeAppearanceDraft current, {
  required List<String> front,
  required HomeThemeModel Function(HomeThemeModel theme) theme,
  required HomeRoomSectionSetting Function(HomeRoomSectionSetting rooms) rooms,
  required HomeEnvironmentSectionSetting Function(
    HomeEnvironmentSectionSetting environment,
  )
  environment,
  required HomeAboutSectionSetting Function(HomeAboutSectionSetting about)
  about,
  required HomeNewsSectionSetting Function(HomeNewsSectionSetting news) news,
  required HomeQuickBookingSectionSetting Function(
    HomeQuickBookingSectionSetting booking,
  )
  quickBooking,
  required HomeInformationSectionsSetting Function(
    HomeInformationSectionsSetting information,
  )
  information,
  required FrontendNavigationConfig Function(
    FrontendNavigationConfig navigation,
  )
  navigation,
  StoreBrandStyle Function(StoreBrandStyle style)? brandStyle,
  HomeQuickActionSetting Function(HomeQuickActionSetting setting)? quickActions,
  HomeSharedEntrySectionSetting Function(HomeSharedEntrySectionSetting setting)?
  sharedEntry,
  HomeDisplayStyleSetting Function(HomeDisplayStyleSetting setting)?
  displayStyle,
  int? bannerButtonColorValue,
  int? bannerButtonTextColorValue,
  required HomeBannerWidthPreset bannerWidth,
  required HomeBannerHeightPreset bannerHeight,
  bool showStayServiceStrip = true,
  String featuredProductLayout = ModernFeaturedProductLayouts.horizontal,
  String storeEntryLayout = ModernStoreEntryLayouts.banner,
}) {
  return current.copyWith(
    theme: theme(current.theme),
    sectionOrder: _ordered(front),
    rooms: rooms(current.rooms),
    environment: environment(current.environment),
    about: about(current.about),
    news: news(current.news),
    quickBooking: quickBooking(current.quickBooking),
    information: information(current.information),
    navigation: navigation(current.navigation),
    brandStyle: brandStyle?.call(current.brandStyle) ?? current.brandStyle,
    quickActions:
        quickActions?.call(current.quickActions) ?? current.quickActions,
    sharedEntry: sharedEntry?.call(current.sharedEntry) ?? current.sharedEntry,
    displayStyle:
        displayStyle?.call(current.displayStyle) ?? current.displayStyle,
    bannerButtonColorValue:
        bannerButtonColorValue ?? current.bannerButtonColorValue,
    bannerButtonTextColorValue:
        bannerButtonTextColorValue ?? current.bannerButtonTextColorValue,
    bannerFrame: current.bannerFrame.copyWith(
      widthPreset: bannerWidth,
      heightPreset: bannerHeight,
    ),
    showStayServiceStrip: showStayServiceStrip,
    featuredProductLayout: featuredProductLayout,
    storeEntryLayout: storeEntryLayout,
  );
}

List<String> _ordered(List<String> front) {
  final List<String> order = <String>[];
  for (final String id in front) {
    if (HomeSectionOrder.defaultOrder.contains(id) && !order.contains(id)) {
      order.add(id);
    }
  }
  for (final String id in HomeSectionOrder.defaultOrder) {
    if (!order.contains(id)) {
      order.add(id);
    }
  }
  return HomeSectionOrder.normalize(order);
}

HomeThemeModel _theme(
  HomeThemeModel theme, {
  required int background,
  required int card,
  required int border,
  required int primary,
  required int text,
  required int secondary,
  required int button,
}) {
  return theme.copyWith(
    backgroundColorValue: background,
    cardColorValue: card,
    cardBorderColorValue: border,
    primaryColorValue: primary,
    textColorValue: text,
    secondaryTextColorValue: secondary,
    buttonBackgroundColorValue: button,
    buttonTextMode: 'light',
    buttonTextColorValue: 0xFFFFFFFF,
    appBackgroundMode: ShopAppBackground.modeColor,
  );
}

StoreBrandStyle _brand(
  StoreBrandStyle style, {
  required int nameColor,
  required int subtitleColor,
  required int headerBackground,
}) {
  return style.copyWith(
    x: 0.5,
    widthRatio: 0.8,
    nameColorValue: nameColor,
    subtitleColorValue: subtitleColor,
    headerBackgroundColorValue: headerBackground,
    textAlign: 'left',
    nameFontSize: 17,
    subtitleFontSize: 11,
    logoPlacement: 'leading',
    logoSize: 'small',
    textShadowEnabled: false,
  );
}

HomeQuickActionSetting _quickActions(
  HomeQuickActionSetting setting, {
  required int background,
  required int icon,
}) {
  return setting.copyWith(
    placement: HomeQuickActionSetting.placementEnd,
    containerStyle: HomeQuickActionSetting.containerCapsule,
    backgroundMode: HomeQuickActionSetting.backgroundCustom,
    backgroundColorValue: background,
    iconColorMode: HomeQuickActionSetting.iconCustom,
    iconColorValue: icon,
    iconSize: HomeQuickActionSetting.sizeSmall,
  );
}

HomeSharedEntrySectionSetting _sharedEntries(
  HomeSharedEntrySectionSetting setting, {
  required int columns,
  required String aspect,
  required String radius,
  required double imageScale,
  required double gapX,
  required double gapY,
  required List<String> cardOrder,
}) {
  final Set<String> existing = setting.cardOrder.toSet();
  final List<String> ordered = <String>[
    for (final String id in cardOrder)
      if (existing.contains(id)) id,
  ];
  final Map<String, HomeSharedEntryCardSetting> cards =
      <String, HomeSharedEntryCardSetting>{
        for (final MapEntry<String, HomeSharedEntryCardSetting> entry
            in setting.cards.entries)
          entry.key: entry.value.copyWith(
            titleColorMode: HomeSharedEntryColorModes.theme,
            bodyColorMode: HomeSharedEntryColorModes.theme,
          ),
      };
  return setting.copyWith(
    enabled: ordered.isNotEmpty,
    columns: columns,
    overflow: HomeSharedEntryOverflows.wrap,
    cardOrder: ordered,
    cards: cards,
    style: setting.style.copyWith(
      aspect: aspect,
      imageFit: 'cover',
      radius: radius,
      textPlacement: HomeSharedEntryPlacements.outsideBelow,
      surface: HomeRoomSimpleSurfaces.filled,
      mask: HomeRoomSimpleMasks.none,
      textAlign: 'center',
      imageScale: imageScale,
      gapX: gapX,
      gapY: gapY,
      gapText: 6,
      insetX: 4,
      showBorder: false,
      cardShadow: 'none',
      textScrim: false,
      iconSize: 38,
    ),
  );
}

HomeDisplayStyleSetting _displayStyle({
  required int text,
  required int secondary,
  required String spacing,
  required String radius,
  required String aspect,
}) {
  return HomeDisplayStyleSetting(
    saved: true,
    style: HomeDisplayStyle(
      titleColor: text,
      bodyColor: secondary,
      colorMode: HomeDisplayColorModes.separate,
      spacing: spacing,
      cardBackground: HomeDisplayBackgrounds.filled,
      cardRadius: radius,
      cardBorder: false,
      cardShadow: HomeDisplayShadows.none,
      imageAspect: aspect,
      imageRadius: radius,
      imageMask: HomeDisplayMasks.none,
    ),
    sections: <String, HomeDisplaySectionChoice>{
      for (final String id in HomeDisplaySections.all)
        id: const HomeDisplaySectionChoice(mode: HomeDisplayStyleModes.inherit),
    },
  );
}

HomeThemeModel _surfaces(
  HomeThemeModel theme, {
  required int background,
  required int card,
  int? border,
  double borderAlpha = 0.16,
}) {
  return theme.copyWith(
    backgroundColorValue: background,
    cardColorValue: card,
    cardBorderColorValue: border ?? _tint(theme.primaryColorValue, borderAlpha),
  );
}

int _tint(int colorValue, double alpha) {
  final Color mixed = Color.alphaBlend(
    Color(colorValue).withValues(alpha: alpha),
    const Color(0xFFFFFFFF),
  );
  return mixed.toARGB32();
}

HomeRoomSectionSetting _scrollRooms(HomeRoomSectionSetting rooms) {
  return rooms.copyWith(layout: HomeRoomSectionLayouts.horizontalScroll);
}

HomeEnvironmentSectionSetting _environment(
  HomeEnvironmentSectionSetting environment, {
  required String layout,
  String imageHeight = HomeEnvironmentImageHeights.standard,
  String cardSize = HomeEnvironmentCardSizes.wide,
}) {
  return environment.copyWith(
    layout: layout,
    imageHeight: imageHeight,
    simpleCardSize: cardSize,
  );
}

HomeAboutSectionSetting _about(
  HomeAboutSectionSetting about, {
  required bool enabled,
  required String layout,
  required String cardSize,
  required String surface,
  bool? showImage,
}) {
  return about.copyWith(
    enabled: enabled,
    layout: layout,
    cardSize: cardSize,
    surfaceStyle: surface,
    showImage: showImage,
  );
}

HomeNewsSectionSetting _news(
  HomeNewsSectionSetting news, {
  required String layout,
  required String surface,
  required bool showSummary,
  bool showEmpty = true,
}) {
  return news.copyWith(
    layout: layout,
    surfaceStyle: surface,
    showSummary: showSummary,
    showEmptyPlaceholder: showEmpty,
  );
}

HomeRoomSectionSetting _entryRooms(HomeRoomSectionSetting rooms) {
  return rooms.copyWith(
    layout: HomeRoomSectionLayouts.simpleEntry,
    simple: rooms.simple.copyWith(cardSize: HomeRoomSimpleCardSizes.small),
  );
}

HomeRoomSectionSetting _featuredRooms(HomeRoomSectionSetting rooms) {
  return rooms.copyWith(layout: HomeRoomSectionLayouts.featured);
}

HomeQuickBookingSectionSetting _booking(
  HomeQuickBookingSectionSetting booking, {
  required String layout,
  required String surface,
}) {
  return booking.copyWith(
    showOnHome: true,
    layout: layout,
    surfaceStyle: surface,
    showAccommodation: true,
    showDaycare: true,
  );
}

HomeInformationSectionsSetting _information(
  HomeInformationSectionsSetting information, {
  required bool policy,
  required String policyLayout,
  required bool faq,
  required String faqLayout,
  required bool reviews,
  required String reviewLayout,
}) {
  return information.copyWith(
    policy: information.policy.copyWith(
      showOnHome: policy,
      layout: policyLayout,
    ),
    faq: information.faq.copyWith(showOnHome: faq, layout: faqLayout),
    reviews: information.reviews.copyWith(
      showOnHome: reviews,
      layout: reviewLayout,
    ),
  );
}

FrontendNavigationConfig _drawer(FrontendNavigationConfig navigation) {
  return navigation.copyWith(style: FrontendNavigationConfig.styleDrawer);
}

FrontendNavigationConfig _bottomAttached(FrontendNavigationConfig navigation) {
  return navigation.copyWith(
    style: FrontendNavigationConfig.styleBottom,
    bottomAppearance: FrontendNavigationConfig.appearanceAttached,
    bottomSurface: FrontendNavigationConfig.surfaceOpaque,
  );
}

FrontendNavigationConfig _bottomFloating(FrontendNavigationConfig navigation) {
  return navigation.copyWith(
    style: FrontendNavigationConfig.styleBottom,
    bottomAppearance: FrontendNavigationConfig.appearanceFloatingPill,
    bottomSurface: FrontendNavigationConfig.surfaceTranslucent,
  );
}
