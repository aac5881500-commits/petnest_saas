import 'home_diary_setting.dart';

/// Decorative settings shared by the storefront and its live editor.
/// Business photos continue to belong to their existing modules.
class HomeStorybookSetting {
  const HomeStorybookSetting({
    this.enabled = false,
    this.diary = const HomeDiarySetting(),
    this.heroSource = 'shop',
    this.heroTitle = '寶貝的安心小假期',
    this.heroSubtitle = '溫柔照護，像在家一樣自在。',
    this.heroButton = '預約住宿',
    this.heroImage = 'cottage',
    this.heroAspect = 2.4,
    this.heroAlign = 'left',
    this.titleSize = 25,
    this.fontFamily = 'jfOpenHuninn',
    this.radius = 24,
    this.padding = 12,
    this.gap = 12,
    this.decoration = 'flowers',
    this.decorationOpacity = .55,
    this.paperColor = 0xFFFFF6D8,
    this.blueColor = 0xFFE5F4FF,
    this.borderColor = 0xFFF2DCA5,
    this.decorateSections = const [
      'quickBooking',
      'announcements',
      'rooms',
      'featured',
      'storeEntrance',
      'about',
      'services',
      'policy',
      'faq',
      'reviews',
      'shopInfo',
    ],
    this.showShortcuts = false,
    this.blueSections = const ['rooms', 'about', 'faq', 'featured'],
  });

  static const heroAsset = 'assets/images/booking_cream_hero_v1.png';
  static const trimAsset = 'assets/images/home_storybook_trim_v1.png';
  final bool enabled, showShortcuts;
  final HomeDiarySetting diary;
  final String fontFamily;
  final String heroSource,
      heroTitle,
      heroSubtitle,
      heroButton,
      heroImage,
      heroAlign,
      decoration;
  final double heroAspect, titleSize, radius, padding, gap, decorationOpacity;
  final int paperColor, blueColor, borderColor;
  final List<String> decorateSections;
  final List<String> blueSections;

  HomeStorybookSetting copyWith({
    bool? enabled,
    HomeDiarySetting? diary,
    bool? showShortcuts,
    String? heroSource,
    String? fontFamily,
    String? heroTitle,
    String? heroSubtitle,
    String? heroButton,
    String? heroImage,
    String? heroAlign,
    String? decoration,
    double? heroAspect,
    double? titleSize,
    double? radius,
    double? padding,
    double? gap,
    double? decorationOpacity,
    int? paperColor,
    int? blueColor,
    int? borderColor,
    List<String>? decorateSections,
    List<String>? blueSections,
  }) => HomeStorybookSetting.fromMap({
    ...toMap(),
    'enabled': ?enabled,
    'diary': ?diary?.toMap(),
    'showShortcuts': ?showShortcuts,
    'heroSource': ?heroSource,
    'fontFamily': ?fontFamily,
    'heroTitle': ?heroTitle,
    'heroSubtitle': ?heroSubtitle,
    'heroButton': ?heroButton,
    'heroImage': ?heroImage,
    'heroAlign': ?heroAlign,
    'decoration': ?decoration,
    'heroAspect': ?heroAspect,
    'titleSize': ?titleSize,
    'radius': ?radius,
    'padding': ?padding,
    'gap': ?gap,
    'decorationOpacity': ?decorationOpacity,
    'paperColor': ?paperColor,
    'blueColor': ?blueColor,
    'borderColor': ?borderColor,
    'decorateSections': ?decorateSections,
    'blueSections': ?blueSections,
  });

  Map<String, dynamic> toMap() => {
    'version': 2,
    'diary': diary.toMap(),
    'enabled': enabled,
    'showShortcuts': showShortcuts,
    'heroSource': heroSource,
    'fontFamily': fontFamily,
    'heroTitle': heroTitle,
    'heroSubtitle': heroSubtitle,
    'heroButton': heroButton,
    'heroImage': heroImage,
    'heroAlign': heroAlign,
    'decoration': decoration,
    'heroAspect': heroAspect,
    'titleSize': titleSize,
    'radius': radius,
    'padding': padding,
    'gap': gap,
    'decorationOpacity': decorationOpacity,
    'paperColor': paperColor,
    'blueColor': blueColor,
    'borderColor': borderColor,
    'decorateSections': decorateSections,
    'blueSections': blueSections,
  };

  factory HomeStorybookSetting.fromMap(dynamic raw) {
    final map = raw is Map ? raw : const {};
    const defaults = HomeStorybookSetting();
    double number(String key, double fallback, double min, double max) {
      final value = map[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(min, max)
          : fallback;
    }

    int color(String key, int fallback) {
      final value = map[key];
      return value is int && value >= 0 && value <= 0xFFFFFFFF
          ? value
          : fallback;
    }

    String text(String key, String fallback) =>
        map[key] is String ? (map[key] as String) : fallback;
    return HomeStorybookSetting(
      blueSections: map['blueSections'] is List
          ? List<String>.unmodifiable(
              (map['blueSections'] as List).whereType<String>().toSet(),
            )
          : defaults.blueSections,
      enabled: map['enabled'] == true,
      diary: HomeDiarySetting.fromMap(map['diary']),
      // First-version presets incorrectly replaced shop photos and added
      // duplicate shortcuts. Reading them corrects only those visual defaults.
      showShortcuts: map['version'] == 2 && map['showShortcuts'] == true,
      heroSource: map['version'] == 2 && map['heroSource'] == 'builtin'
          ? 'builtin'
          : 'shop',
      fontFamily:
          const [
            'jfOpenHuninn',
            'NotoSansTC',
            'KleeOne',
          ].contains(map['fontFamily'])
          ? map['fontFamily'] as String
          : defaults.fontFamily,
      heroImage: map['heroImage'] == 'none' ? 'none' : 'cottage',
      heroAlign: map['heroAlign'] == 'center' ? 'center' : 'left',
      heroTitle: text('heroTitle', defaults.heroTitle),
      heroSubtitle: text('heroSubtitle', defaults.heroSubtitle),
      heroButton: text('heroButton', defaults.heroButton),
      heroAspect: number('heroAspect', 2.4, 1.2, 4),
      titleSize: number('titleSize', 25, 18, 40),
      radius: number('radius', 24, 0, 40),
      padding: number('padding', 12, 0, 24),
      gap: number('gap', 12, 4, 32),
      decorationOpacity: number('decorationOpacity', .55, 0, 1),
      decoration: map['decoration'] == 'none' ? 'none' : 'flowers',
      paperColor: color('paperColor', defaults.paperColor),
      blueColor: color('blueColor', defaults.blueColor),
      borderColor: color('borderColor', defaults.borderColor),
      decorateSections: map['decorateSections'] is List
          ? List<String>.unmodifiable(
              (map['decorateSections'] as List).whereType<String>().toSet(),
            )
          : defaults.decorateSections,
    );
  }
}
