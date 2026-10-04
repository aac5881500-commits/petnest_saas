import 'package:petnest_saas/core/models/home_environment_section_setting.dart';

/// 新版首頁關於我們區塊。內容仍來自既有 about 欄位，這裡只決定怎麼顯示。
class HomeAboutLayouts {
  static const String simpleEntry = 'simpleEntry';
  static const String imageEntry = 'imageEntry';
  static const String brandIntro = 'brandIntro';
  static const List<String> all = <String>[simpleEntry, imageEntry, brandIntro];

  static String label(String value) {
    switch (migrate(value)) {
      case imageEntry:
        return '圖文介紹';
      case brandIntro:
        return '品牌介紹';
      default:
        return '簡約入口';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return simpleEntry;
  }
}

class HomeAboutCardSizes {
  static const String small = 'small';
  static const String standard = 'standard';
  static const String wide = 'wide';
  static const List<String> all = <String>[small, standard, wide];

  static String label(String value) {
    switch (migrate(value)) {
      case small:
        return '小卡';
      case wide:
        return '長卡';
      default:
        return '標準橫卡';
    }
  }

  /// Firestore 的 cardSize 對應入口卡。small→small、standard→wide、wide→single。
  static String entryCardSize(String value) {
    switch (migrate(value)) {
      case small:
        return 'small';
      case wide:
        return 'single';
      default:
        return 'wide';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return standard;
  }
}

class HomeAboutImagePositions {
  static const String left = 'left';
  static const String right = 'right';
  static const String top = 'top';
  static const List<String> all = <String>[left, right, top];

  static String label(String value) {
    switch (migrate(value)) {
      case right:
        return '右圖左文';
      case top:
        return '上圖下文';
      default:
        return '左圖右文';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return left;
  }
}

class HomeAboutImageFits {
  static const String cover = 'cover';
  static const String contain = 'contain';
  static const List<String> all = <String>[cover, contain];

  static String migrate(Object? raw) {
    return raw?.toString().trim() == contain ? contain : cover;
  }
}

class HomeAboutImageAligns {
  static const String top = 'top';
  static const String center = 'center';
  static const String bottom = 'bottom';
  static const List<String> all = <String>[top, center, bottom];

  static String label(String value) {
    switch (migrate(value)) {
      case top:
        return '偏上';
      case bottom:
        return '偏下';
      default:
        return '置中';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return center;
  }
}

class HomeAboutSurfaces {
  static const String solid = 'solid';
  static const String translucent = 'translucent';
  static const String transparent = 'transparent';
  static const List<String> all = <String>[solid, translucent, transparent];

  static String label(String value) {
    switch (migrate(value)) {
      case translucent:
        return '半透明';
      case transparent:
        return '透明';
      default:
        return '實色';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return solid;
  }

  static String entrySurface(String value) {
    switch (migrate(value)) {
      case translucent:
        return 'translucent';
      case transparent:
        return 'transparent';
      default:
        return 'filled';
    }
  }
}

class HomeAboutTextAligns {
  static const String left = 'left';
  static const String center = 'center';
  static const List<String> all = <String>[left, center];

  static String label(String value) {
    return migrate(value) == center ? '置中' : '靠左';
  }

  static String migrate(Object? raw) {
    return raw?.toString().trim() == center ? center : left;
  }
}

class HomeAboutSectionSetting {
  const HomeAboutSectionSetting({
    this.schemaVersion = 1,
    this.enabled = false,
    this.layout = HomeAboutLayouts.simpleEntry,
    this.cardSize = HomeAboutCardSizes.standard,
    this.title = '關於我們',
    this.useShopNameAsTitle = true,
    this.subtitle = '認識我們的照顧理念',
    this.showSubtitle = true,
    this.showImage = true,
    this.imageUrl = '',
    this.imageFit = HomeAboutImageFits.cover,
    this.imagePosition = HomeAboutImagePositions.left,
    this.imageAlign = HomeAboutImageAligns.center,
    this.showLogo = true,
    this.showArrow = true,
    this.showButton = true,
    this.buttonText = '認識我們',
    this.surfaceStyle = HomeAboutSurfaces.solid,
    this.textAlign = HomeAboutTextAligns.left,
  });

  final int schemaVersion;
  final bool enabled;
  final String layout;
  final String cardSize;
  final String title;
  final bool useShopNameAsTitle;
  final String subtitle;
  final bool showSubtitle;
  final bool showImage;
  final String imageUrl;
  final String imageFit;
  final String imagePosition;
  final String imageAlign;
  final bool showLogo;
  final bool showArrow;
  final bool showButton;
  final String buttonText;
  final String surfaceStyle;
  final String textAlign;

  bool get showsOnHome => enabled;

  /// 只有簡約入口的小卡占半排。其餘版型與尺寸獨占一排。
  bool get isHalf {
    return HomeAboutLayouts.migrate(layout) == HomeAboutLayouts.simpleEntry &&
        HomeAboutCardSizes.migrate(cardSize) == HomeAboutCardSizes.small;
  }

  String get entryTitle {
    final String text = title.trim();
    return text.isEmpty ? '關於我們' : text;
  }

  String get entryButton {
    final String text = buttonText.trim();
    return text.isEmpty ? '認識我們' : text;
  }

  HomeAboutSectionSetting copyWith({
    int? schemaVersion,
    bool? enabled,
    String? layout,
    String? cardSize,
    String? title,
    bool? useShopNameAsTitle,
    String? subtitle,
    bool? showSubtitle,
    bool? showImage,
    String? imageUrl,
    String? imageFit,
    String? imagePosition,
    String? imageAlign,
    bool? showLogo,
    bool? showArrow,
    bool? showButton,
    String? buttonText,
    String? surfaceStyle,
    String? textAlign,
  }) {
    return HomeAboutSectionSetting(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      enabled: enabled ?? this.enabled,
      layout: layout ?? this.layout,
      cardSize: cardSize ?? this.cardSize,
      title: title ?? this.title,
      useShopNameAsTitle: useShopNameAsTitle ?? this.useShopNameAsTitle,
      subtitle: subtitle ?? this.subtitle,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      showImage: showImage ?? this.showImage,
      imageUrl: imageUrl ?? this.imageUrl,
      imageFit: imageFit ?? this.imageFit,
      imagePosition: imagePosition ?? this.imagePosition,
      imageAlign: imageAlign ?? this.imageAlign,
      showLogo: showLogo ?? this.showLogo,
      showArrow: showArrow ?? this.showArrow,
      showButton: showButton ?? this.showButton,
      buttonText: buttonText ?? this.buttonText,
      surfaceStyle: surfaceStyle ?? this.surfaceStyle,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'enabled': enabled,
      'layout': HomeAboutLayouts.migrate(layout),
      'cardSize': HomeAboutCardSizes.migrate(cardSize),
      'title': title,
      'useShopNameAsTitle': useShopNameAsTitle,
      'subtitle': subtitle,
      'showSubtitle': showSubtitle,
      'showImage': showImage,
      'imageUrl': imageUrl.trim(),
      'imageFit': HomeAboutImageFits.migrate(imageFit),
      'imagePosition': HomeAboutImagePositions.migrate(imagePosition),
      'imageAlign': HomeAboutImageAligns.migrate(imageAlign),
      'showLogo': showLogo,
      'showArrow': showArrow,
      'showButton': showButton,
      'buttonText': buttonText,
      'surfaceStyle': HomeAboutSurfaces.migrate(surfaceStyle),
      'textAlign': HomeAboutTextAligns.migrate(textAlign),
    };
  }

  static HomeAboutSectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeAboutSectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String title = _clip(map['title'], 24);
    final String subtitle = _clip(map['subtitle'], 80);
    final String button = _clip(map['buttonText'], 12);
    return HomeAboutSectionSetting(
      schemaVersion: map['schemaVersion'] is num
          ? (map['schemaVersion'] as num).toInt()
          : 1,
      enabled: map['enabled'] == true,
      layout: HomeAboutLayouts.migrate(map['layout']),
      cardSize: HomeAboutCardSizes.migrate(map['cardSize']),
      title: title.isEmpty ? '關於我們' : title,
      useShopNameAsTitle: map['useShopNameAsTitle'] is bool
          ? map['useShopNameAsTitle'] as bool
          : true,
      subtitle: subtitle.isEmpty ? '認識我們的照顧理念' : subtitle,
      showSubtitle: map['showSubtitle'] is bool
          ? map['showSubtitle'] as bool
          : true,
      showImage: map['showImage'] is bool ? map['showImage'] as bool : true,
      imageUrl: (map['imageUrl'] ?? '').toString().trim(),
      imageFit: HomeAboutImageFits.migrate(map['imageFit']),
      imagePosition: HomeAboutImagePositions.migrate(map['imagePosition']),
      imageAlign: HomeAboutImageAligns.migrate(map['imageAlign']),
      showLogo: map['showLogo'] is bool ? map['showLogo'] as bool : true,
      showArrow: map['showArrow'] is bool ? map['showArrow'] as bool : true,
      showButton: map['showButton'] is bool ? map['showButton'] as bool : true,
      buttonText: button.isEmpty ? '認識我們' : button,
      surfaceStyle: HomeAboutSurfaces.migrate(map['surfaceStyle']),
      textAlign: HomeAboutTextAligns.migrate(map['textAlign']),
    );
  }

  /// 指定圖 → 關於我們封面 → Logo → 環境照片。都沒有就回傳空字串。
  static String resolveImageUrl({
    required HomeAboutSectionSetting setting,
    required Map<String, dynamic> shop,
    required Map<String, dynamic> environmentIntro,
  }) {
    final String chosen = setting.imageUrl.trim();
    if (chosen.isNotEmpty) {
      return chosen;
    }
    final String cover = (shop['aboutImageUrl'] ?? '').toString().trim();
    if (cover.isNotEmpty) {
      return cover;
    }
    final String logo = (shop['logoUrl'] ?? '').toString().trim();
    if (logo.isNotEmpty) {
      return logo;
    }
    return HomeEnvironmentSectionSetting.resolveImageUrl(environmentIntro);
  }

  static List<Map<String, String>> imageChoices({
    required Map<String, dynamic> shop,
    required Map<String, dynamic> environmentIntro,
  }) {
    final List<Map<String, String>> items = <Map<String, String>>[];
    void add(String label, String url) {
      final String value = url.trim();
      if (value.isEmpty ||
          items.any((Map<String, String> item) => item['url'] == value)) {
        return;
      }
      items.add(<String, String>{'label': label, 'url': value});
    }

    add('關於我們封面', (shop['aboutImageUrl'] ?? '').toString());
    add('店家 Logo', (shop['logoUrl'] ?? '').toString());
    add(
      '環境照片',
      HomeEnvironmentSectionSetting.resolveImageUrl(environmentIntro),
    );
    return items;
  }
}

/// 獨立關於我們區塊有顯示時，住宿服務不再放同一個入口。
bool stayServiceShowsAbout(HomeAboutSectionSetting setting) {
  return !setting.showsOnHome;
}

String _clip(Object? raw, int maxCharacters) {
  final String value = raw?.toString().trim() ?? '';
  if (value.length <= maxCharacters) {
    return value;
  }
  return value.substring(0, maxCharacters);
}
