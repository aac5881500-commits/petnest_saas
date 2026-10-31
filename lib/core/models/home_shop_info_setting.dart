import 'home_card_image_setting.dart';

/// Appearance only; business contact details remain in the shop profile.
class HomeShopInfoSetting {
  const HomeShopInfoSetting({
    this.enabled = true,
    this.mode = 'auto',
    this.preset = 'warm',
    this.followTheme = true,
    this.layout = 'stacked',
    this.imageSource = 'logo',
    this.imageUrl = '',
    this.libraryImage = const HomeCardImageSetting(),
    this.imageFit = 'cover',
    this.radius = 20,
    this.buttonStyle = 'outlined',
    this.showName = true,
    this.showIntro = true,
    this.showActions = true,
    this.fields = const ['hours', 'address', 'phone', 'license', 'tax'],
  });
  static const mapKey = 'shopInfo';
  static const modes = {
    'auto': '沿用原本方式',
    'scroll': '隨整頁捲動・完整顯示',
    'scrollCollapsed': '隨整頁捲動・點擊展開',
    'pull': '固定底部・可上拉展開',
    'compact': '固定底部・精簡資訊列',
  };
  static const layouts = {
    'stacked': '直式資訊卡',
    'side': '照片與店名並排',
    'banner': '橫幅大照片',
    'centered': '置中品牌',
    'plain': '純文字頁尾',
  };
  static const fieldLabels = {
    'hours': '營業時間',
    'address': '地址',
    'phone': '電話',
    'license': '特寵字號',
    'tax': '統一編號（仍受基本資料公開設定限制）',
  };
  final bool enabled, followTheme, showName, showIntro, showActions;
  final String mode,
      preset,
      layout,
      imageSource,
      imageUrl,
      imageFit,
      buttonStyle;
  final HomeCardImageSetting libraryImage;
  final double radius;
  final List<String> fields;
  String resolvedMode(bool bottomNavigation) =>
      mode == 'auto' ? (bottomNavigation ? 'scrollCollapsed' : 'pull') : mode;
  bool isFixed(bool bottomNavigation) =>
      enabled &&
      const ['pull', 'compact'].contains(resolvedMode(bottomNavigation));
  HomeShopInfoSetting copyWith({
    bool? enabled,
    bool? followTheme,
    bool? showName,
    bool? showIntro,
    bool? showActions,
    String? mode,
    String? preset,
    String? layout,
    String? imageSource,
    String? imageUrl,
    String? imageFit,
    String? buttonStyle,
    HomeCardImageSetting? libraryImage,
    double? radius,
    List<String>? fields,
  }) => HomeShopInfoSetting(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    preset: preset ?? this.preset,
    followTheme: followTheme ?? this.followTheme,
    layout: layout ?? this.layout,
    imageSource: imageSource ?? this.imageSource,
    imageUrl: imageUrl ?? this.imageUrl,
    imageFit: imageFit ?? this.imageFit,
    buttonStyle: buttonStyle ?? this.buttonStyle,
    libraryImage: libraryImage ?? this.libraryImage,
    radius: radius ?? this.radius,
    showName: showName ?? this.showName,
    showIntro: showIntro ?? this.showIntro,
    showActions: showActions ?? this.showActions,
    fields: fields ?? this.fields,
  );
  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'mode': mode,
    'preset': preset,
    'followTheme': followTheme,
    'layout': layout,
    'imageSource': imageSource,
    'imageUrl': imageUrl,
    'libraryImage': libraryImage.toMap(),
    'imageFit': imageFit,
    'radius': radius,
    'buttonStyle': buttonStyle,
    'showName': showName,
    'showIntro': showIntro,
    'showActions': showActions,
    'fields': fields,
  };
  static HomeShopInfoSetting fromShop(Map<String, dynamic> shop) {
    final appearance = shop['homeAppearance'];
    final modern = appearance is Map ? appearance['modern'] : null;
    return fromMap(modern is Map ? modern[mapKey] : null);
  }

  static HomeShopInfoSetting fromMap(Object? raw) {
    if (raw is! Map) return const HomeShopInfoSetting();
    String choice(String key, Iterable<String> values, String fallback) =>
        values.contains(raw[key]) ? raw[key] as String : fallback;
    bool flag(String key, bool fallback) =>
        raw[key] is bool ? raw[key] as bool : fallback;
    final url = (raw['imageUrl'] ?? '').toString().trim();
    final uri = Uri.tryParse(url);
    final r = raw['radius'];
    return HomeShopInfoSetting(
      enabled: flag('enabled', true),
      mode: choice('mode', modes.keys, 'auto'),
      preset: choice('preset', shopInfoPresets.map((p) => p.id), 'warm'),
      followTheme: flag('followTheme', true),
      layout: choice('layout', layouts.keys, 'stacked'),
      imageSource: choice('imageSource', [
        'none',
        'logo',
        'photo',
        'library',
      ], 'logo'),
      imageUrl: uri?.scheme == 'https' && uri!.host.isNotEmpty ? url : '',
      libraryImage: HomeCardImageSetting.fromMap(raw['libraryImage']),
      imageFit: choice('imageFit', ['cover', 'contain'], 'cover'),
      radius: r is num && r.isFinite ? r.toDouble().clamp(0, 32) : 20,
      buttonStyle: choice('buttonStyle', [
        'outlined',
        'filled',
        'text',
      ], 'outlined'),
      showName: flag('showName', true),
      showIntro: flag('showIntro', true),
      showActions: flag('showActions', true),
      fields: raw['fields'] is List
          ? (raw['fields'] as List)
                .whereType<String>()
                .where(fieldLabels.containsKey)
                .toSet()
                .toList()
          : const ['hours', 'address', 'phone', 'license', 'tax'],
    );
  }
}

class ShopInfoPreset {
  const ShopInfoPreset(
    this.id,
    this.label,
    this.accent,
    this.surface,
    this.text,
    this.layout,
  );
  final String id, label, layout;
  final int accent, surface, text;
}

/// Footer treatments inspired by the ten mockups, without their proposed future features.
const shopInfoPresets = [
  ShopInfoPreset('warm', 'A1 奶油暖橘', 0xFFD66C09, 0xFFFFF8EF, 0xFF493426, 'side'),
  ShopInfoPreset(
    'forest',
    'A2 日系森林',
    0xFF52705D,
    0xFFF3F6F0,
    0xFF34463B,
    'stacked',
  ),
  ShopInfoPreset(
    'boutique',
    'A3 精品旅宿',
    0xFFD8BA86,
    0xFF342D26,
    0xFFFFF7EC,
    'centered',
  ),
  ShopInfoPreset(
    'peach',
    'A4 蜜桃貓咪',
    0xFFAD5950,
    0xFFFFF0EB,
    0xFF593C37,
    'side',
  ),
  ShopInfoPreset(
    'blue',
    'A5 清爽導購',
    0xFFC4E6FF,
    0xFF264C68,
    0xFFFFFFFF,
    'plain',
  ),
  ShopInfoPreset(
    'natural',
    'B1 自然選房風',
    0xFF56674E,
    0xFFF3F2E9,
    0xFF3D4638,
    'centered',
  ),
  ShopInfoPreset(
    'panorama',
    'B2 香檳大圖風',
    0xFF926B36,
    0xFFFFF9F1,
    0xFF47372A,
    'banner',
  ),
  ShopInfoPreset(
    'journey',
    'B3 溫暖旅程風',
    0xFFCC5C0E,
    0xFFFFF4E6,
    0xFF57391F,
    'stacked',
  ),
  ShopInfoPreset(
    'clear',
    'B4 清透藍白風',
    0xFF216692,
    0xFFEFF8FF,
    0xFF20485F,
    'plain',
  ),
  ShopInfoPreset(
    'journal',
    'B5 玫瑰生活誌',
    0xFFA65D52,
    0xFFFFF6F2,
    0xFF633E38,
    'banner',
  ),
];
