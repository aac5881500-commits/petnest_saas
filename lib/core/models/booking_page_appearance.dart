import 'home_theme_model.dart';

// 預約頁外觀；缺少設定時沿用原始版面。
class BookingPageAppearance {
  const BookingPageAppearance({
    this.reminderTitle = '預約前提醒',
    this.note = '',
    this.style = 'warm',
    this.compact = false,
    this.narrow = false,
    this.looks = const {},
  });
  final Map<String, BookingPageLook> looks;
  bool get lookEditable => style != 'cream' && style != 'house';
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
      textColorValue: look.text ?? base.textColorValue,
      primaryColorValue: look.primary ?? base.primaryColorValue,
    );
  }

  final String reminderTitle, note, style;
  static const styles = <String, String>{
    'original': '最初版本',
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
      note: data['note'] is String ? data['note'] : '',
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
    this.followFrontend = false,
  });
  final int? background, text, primary;
  final String font;
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
  factory BookingPageLook.fromMap(Map data) => BookingPageLook(
    followFrontend: data['followFrontend'] == true,
    background: backgrounds.containsKey(data['background'])
        ? data['background']
        : null,
    text: texts.containsKey(data['text']) ? data['text'] : null,
    primary: primaries.containsKey(data['primary']) ? data['primary'] : null,
    font: fonts.containsKey(data['font']) ? data['font'] : '',
  );
  Map<String, dynamic> toMap() => {
    if (followFrontend) 'followFrontend': true,
    if (background != null) 'background': background,
    if (text != null) 'text': text,
    if (primary != null) 'primary': primary,
    'font': font,
  };
}
