import 'home_theme_model.dart';

// 預約頁外觀；缺少設定時沿用原始版面。
class BookingPageAppearance {
  const BookingPageAppearance({
    this.reminderTitle = '預約前提醒',
    this.note = '',
    this.style = 'warm',
    this.serviceStyle = 'original',
    this.suiteColorMode = 'template',
    this.heroImage = '',
    this.compact = false,
    this.narrow = false,
    this.looks = const {},
    this.calendarStyle = 'classic',
    this.calendarPresentation = 'dialog',
    this.calendarDensity = 'compact',
    this.calendarColorMode = 'template',
    this.calendarBackground = 0xFFF0F7F2,
    this.calendarAccent = 0xFF34786B,
  });
  final String suiteColorMode, heroImage;
  static const defaultHero =
      'assets/images/shop_house/modern_japanese/modern_japanese_cat_default.jpg';
  static const suiteServiceStyles = {
    'original': 'original',
    'editorial': 'editorial',
    'cream': 'cream',
    'house': 'journal',
    'warm': 'original',
    'boutique': 'premium',
    'minimal': 'original',
    'soft': 'journal',
    'compact': 'premium',
  };
  final String serviceStyle;
  static const serviceStyles = {
    'original': '原版',
    'cream': '韓系奶油套裝',
    'editorial': 'A 旅宿雜誌風',
    'journal': 'C 奶油手帳風',
    'premium': 'D 沉穩精品風',
  };
  final String calendarStyle, calendarPresentation, calendarDensity;
  final String calendarColorMode;
  final int calendarBackground, calendarAccent;
  int? calendarBackgroundFor(HomeThemeModel page) =>
      switch (calendarColorMode) {
        'page' => page.backgroundColorValue,
        'custom' => calendarBackground,
        _ => null,
      };
  int? calendarAccentFor(HomeThemeModel page) => switch (calendarColorMode) {
    'page' => page.primaryColorValue,
    'custom' => calendarAccent,
    _ => null,
  };
  static const calendarStyles = {
    'classic': '經典月曆',
    'stay': '旅宿日期卡',
    'week': '週曆時間軸',
    'journal': '日程清單',
    'board': '週末旅行板',
    'ribbon': '旅程長票',
    'weekbands': '整月週次表',
    'monthlist': '整月日期索引',
    'monthwall': '整月卡片牆',
    'minimal': '清爽留白',
    'round': '圓形日期',
    'soft': '柔和色塊',
  };
  static const monthCalendarStyles = {
    'classic',
    'stay',
    'weekbands',
    'monthlist',
    'monthwall',
  };
  static const weekCalendarStyles = {'week', 'journal', 'board', 'ribbon'};
  static const calendarPresentations = {
    'dialog': '置中視窗',
    'summary': '日期摘要視窗',
    'sheet': '底部滑出',
  };
  static const calendarDensities = {'compact': '精簡', 'comfortable': '寬鬆'};
  final Map<String, BookingPageLook> looks;
  bool get lookEditable => true;
  BookingPageLook get look => lookEditable
      ? looks[style] ?? const BookingPageLook()
      : const BookingPageLook();
  static HomeThemeModel frontendThemeFromShop(
    Map<String, dynamic>? shop, {
    HomeThemeModel fallback = HomeThemeModel.modernDefault,
  }) {
    final home = shop?['homeAppearance'];
    if (home is! Map) return fallback;
    if (home['layout'] == 'modern') {
      final modern = home['modern'];
      return HomeThemeModel.fromMap(
        modern is Map ? modern['themeColors'] : null,
        fallback: fallback,
      );
    }
    return HomeThemeModel.fromClassicSettings(rawData: home['classic'] ?? home);
  }

  HomeThemeModel applyLook(
    HomeThemeModel base, {
    HomeThemeModel? frontendTheme,
  }) {
    final source = frontendTheme ?? base;
    if (suiteColorMode == 'frontend') {
      return source.copyWith(cardColorValue: source.backgroundColorValue);
    }
    return base.copyWith(
      backgroundColorValue: look.followFrontend
          ? source.backgroundColorValue
          : look.background ?? base.backgroundColorValue,
      appBackgroundMode: look.followFrontend
          ? source.appBackgroundMode
          : ShopAppBackground.modeColor,
      appBackgroundAssetId: look.followFrontend
          ? source.appBackgroundAssetId
          : '',
      appBackgroundFit: look.followFrontend
          ? source.appBackgroundFit
          : ShopAppBackground.fitCover,
      appBackgroundAlign: look.followFrontend
          ? source.appBackgroundAlign
          : ShopAppBackground.alignCenter,
      appBackgroundScrim: look.followFrontend
          ? source.appBackgroundScrim
          : ShopAppBackground.defaultScrim,
      cardColorValue: look.background ?? base.cardColorValue,
      textColorValue: look.text ?? base.textColorValue,
      primaryColorValue: look.primary ?? base.primaryColorValue,
    );
  }

  final String reminderTitle, note, style;
  static const styles = <String, String>{
    'original': '最初版本',
    'editorial': '旅宿雜誌・三頁套裝',
    'cream': '韓系奶油',
    'house': '圓潤小屋',
    'warm': '月曆直選',
    'boutique': '旅宿大圖',
    'minimal': '逐步問答',
    'soft': '貓咪先行',
    'compact': '預約工作台',
  };
  static const descriptions = <String, String>{
    'original': '日期 → 提醒 → 貓咪・原始卡片排版',
    'editorial': '日期貓咪・房型服務・費用確認，完整三頁套裝',
    'cream': '貓咪插畫・藍黃照片卡・膠囊日期',
    'house': '屋頂頁首・拱形照片卡・淺藍日期區',
    'warm': '完整月曆・先選日期再選貓咪',
    'boutique': '沉浸大圖・入住日期搜尋面板',
    'minimal': '一次一題・可返回修改的引導',
    'soft': '大頭照選貓・旅程時間軸',
    'compact': '預約摘要・桌面雙欄工作區',
  };
  final bool compact, narrow;
  static const path = 'homeAppearance.bookingPage';
  factory BookingPageAppearance.fromShop(Map<String, dynamic>? shop) {
    final home = shop?['homeAppearance'];
    final data = home is Map ? home['bookingPage'] : null;
    if (data is! Map) return const BookingPageAppearance();
    return BookingPageAppearance(
      reminderTitle:
          data['reminderTitle'] is String &&
              (data['reminderTitle'] as String).trim().isNotEmpty
          ? data['reminderTitle']
          : '預約前提醒',
      style: styles.containsKey(data['style']) ? data['style'] : 'warm',
      serviceStyle: data['style'] == 'cream'
          ? 'cream'
          : serviceStyles.containsKey(data['serviceStyle'])
          ? data['serviceStyle']
          : 'original',
      suiteColorMode:
          const [
            'template',
            'frontend',
            'custom',
          ].contains(data['suiteColorMode'])
          ? data['suiteColorMode']
          : ((data['looks'] is Map && (data['looks'] as Map).isNotEmpty)
                ? 'custom'
                : 'template'),
      heroImage:
          data['heroImage'] is String &&
              ((data['heroImage'] as String).startsWith('https://') ||
                  (data['heroImage'] as String).startsWith('assets/images/'))
          ? data['heroImage']
          : '',
      note: data['note'] is String ? data['note'] : '',
      calendarStyle: calendarStyles.containsKey(data['calendarStyle'])
          ? data['calendarStyle']
          : 'classic',
      calendarPresentation:
          calendarPresentations.containsKey(data['calendarPresentation'])
          ? data['calendarPresentation']
          : 'dialog',
      calendarDensity: calendarDensities.containsKey(data['calendarDensity'])
          ? data['calendarDensity']
          : 'compact',
      calendarColorMode:
          const [
            'template',
            'page',
            'custom',
          ].contains(data['calendarColorMode'])
          ? data['calendarColorMode']
          : 'template',
      calendarBackground: data['calendarBackground'] is int
          ? data['calendarBackground']
          : 0xFFF0F7F2,
      calendarAccent: data['calendarAccent'] is int
          ? data['calendarAccent']
          : 0xFF34786B,
      looks: data['looks'] is Map
          ? {
              for (final entry in (data['looks'] as Map).entries)
                if (styles.containsKey(entry.key) && entry.value is Map)
                  entry.key.toString(): BookingPageLook.fromMap(entry.value),
            }
          : const {},
      compact: data['compact'] == true,
      narrow: data['narrow'] == true,
    );
  }
  Map<String, dynamic> toMap() => {
    'reminderTitle': reminderTitle,
    'note': note,
    'style': style,
    'serviceStyle': serviceStyle,
    'suiteColorMode': suiteColorMode,
    'heroImage': heroImage,
    'calendarStyle': calendarStyle,
    'calendarPresentation': calendarPresentation,
    'calendarDensity': calendarDensity,
    'calendarColorMode': calendarColorMode,
    'calendarBackground': calendarBackground,
    'calendarAccent': calendarAccent,
    'compact': compact,
    'narrow': narrow,
    if (looks.isNotEmpty)
      'looks': looks.map((key, value) => MapEntry(key, value.toMap())),
  };
}

class BookingPageLook {
  const BookingPageLook({
    this.background,
    this.text,
    this.primary,
    this.font = '',
    this.fontWeight,
    this.followFrontend = false,
  });
  final int? background, text, primary;
  final String font;
  final int? fontWeight;
  final bool followFrontend;
  static const backgrounds = <int, String>{
    0xFFFFFFFF: '白色',
    0xFFFFF9F0: '奶油',
    0xFFF0F6FC: '淺藍',
    0xFFF0F7F2: '淺綠',
    0xFFF8F3FC: '淡紫',
    0xFFFFF2F0: '淡粉',
  };
  static const texts = <int, String>{
    0xFF263238: '深灰',
    0xFF603B28: '暖棕',
    0xFF233D36: '墨綠',
    0xFF273B59: '深藍',
    0xFF493853: '深紫',
  };
  static const primaries = <int, String>{
    0xFF3878AC: '藍色',
    0xFF39775D: '綠色',
    0xFFAE6030: '暖橘',
    0xFF6554A5: '紫色',
    0xFFAD526A: '玫瑰',
  };
  static const fonts = <String, String>{
    '': '版型預設',
    'NotoSansTC': '思源黑體',
    'jfOpenHuninn': '粉圓體',
    'NotoSerifTC': '思源宋體',
    'KleeOne': '手寫體',
  };
  static int? _color(Object? value) =>
      value is int && value >= 0xFF000000 && value <= 0xFFFFFFFF ? value : null;
  factory BookingPageLook.fromMap(Map data) => BookingPageLook(
    followFrontend: data['followFrontend'] == true,
    background: _color(data['background']),
    text: _color(data['text']),
    primary: _color(data['primary']),
    font: fonts.containsKey(data['font']) ? data['font'] : '',
    fontWeight: const [400, 500, 600, 700, 800].contains(data['fontWeight'])
        ? data['fontWeight']
        : null,
  );
  Map<String, dynamic> toMap() => {
    if (followFrontend) 'followFrontend': true,
    if (background != null) 'background': background,
    if (text != null) 'text': text,
    if (primary != null) 'primary': primary,
    'font': font,
    if (fontWeight != null) 'fontWeight': fontWeight,
  };
}
