import 'home_card_image_setting.dart';

/// Appearance only; business contact details remain in the shop profile.
class HomeShopInfoSetting {
  const HomeShopInfoSetting({
    this.actionIds = const ['phone', 'map', 'line', 'instagram', 'facebook'],
    this.actionLayout = 'wrap',
    this.actionPresentation = 'standard',
    this.photoShape = 'rounded',
    this.decoration = 'none',
    this.phoneLabel = '電話聯絡',
    this.mapLabel = '查看地圖',
    this.lineLabel = '加入 LINE',
    this.sectionTitle = '店家資訊',
    this.photoFraction = .36,
    bool enabled = true,
    this.mode = 'auto',
    this.preset = 'warm',
    this.followTheme = true,
    this.layout = 'stacked',
    this.imageSource = 'logo',
    this.imageUrl = '',
    this.introText,
    this.libraryImage = const HomeCardImageSetting(),
    this.imageFit = 'cover',
    this.radius = 20,
    this.buttonStyle = 'outlined',
    bool showName = true,
    bool showIntro = true,
    bool showActions = true,
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
    'photoContact': '左側照片・右側資訊與聯絡按鈕',
    'stacked': '直式資訊卡',
    'side': '照片與店名並排',
    'banner': '橫幅大照片',
    'centered': '置中品牌',
    'plain': '純文字頁尾',
    'infoActions': '左側資訊・右側聯絡按鈕',
    'brandColumns': '品牌・資訊・聯絡三欄',
    'photoDetails': '左側照片・右側品牌資訊',
    'brandSplit': '左側品牌・右側資訊與按鈕',
    'photoThree': '照片・資訊・直排按鈕',
    'photoRight': '左側資訊・右側照片與按鈕',
    'editorialPhoto': '左側大照片・右側完整資訊',
  };
  static const fieldLabels = {
    'hours': '營業時間',
    'address': '地址',
    'phone': '電話',
    'license': '特寵字號',
    'tax': '統一編號（仍受基本資料公開設定限制）',
  };
  final List<String> actionIds;
  final String actionLayout, phoneLabel, mapLabel, lineLabel, sectionTitle;
  final String actionPresentation, photoShape, decoration;
  final double photoFraction;
  final bool followTheme;
  // Required shop information is temporarily always visible, including legacy data.
  bool get enabled => true;
  bool get showName => true;
  bool get showIntro => true;
  bool get showActions => true;
  final String? introText;
  List<String> get orderedFields => <String>{
    ...fields.where(fieldLabels.containsKey),
    ...fieldLabels.keys,
  }.toList();
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
    List<String>? actionIds,
    String? actionLayout,
    String? actionPresentation,
    String? photoShape,
    String? decoration,
    String? phoneLabel,
    String? mapLabel,
    String? lineLabel,
    String? sectionTitle,
    double? photoFraction,
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
    String? introText,
    String? imageFit,
    String? buttonStyle,
    HomeCardImageSetting? libraryImage,
    double? radius,
    List<String>? fields,
  }) => HomeShopInfoSetting(
    actionIds: actionIds ?? this.actionIds,
    actionLayout: actionLayout ?? this.actionLayout,
    actionPresentation: actionPresentation ?? this.actionPresentation,
    photoShape: photoShape ?? this.photoShape,
    decoration: decoration ?? this.decoration,
    phoneLabel: phoneLabel ?? this.phoneLabel,
    mapLabel: mapLabel ?? this.mapLabel,
    lineLabel: lineLabel ?? this.lineLabel,
    sectionTitle: sectionTitle ?? this.sectionTitle,
    photoFraction: photoFraction ?? this.photoFraction,
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    preset: preset ?? this.preset,
    followTheme: followTheme ?? this.followTheme,
    layout: layout ?? this.layout,
    imageSource: imageSource ?? this.imageSource,
    imageUrl: imageUrl ?? this.imageUrl,
    introText: introText ?? this.introText,
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
    'actionIds': actionIds,
    'actionLayout': actionLayout,
    'actionPresentation': actionPresentation,
    'photoShape': photoShape,
    'decoration': decoration,
    'phoneLabel': phoneLabel,
    'mapLabel': mapLabel,
    'lineLabel': lineLabel,
    'sectionTitle': sectionTitle,
    'photoFraction': photoFraction,
    'enabled': enabled,
    'mode': mode,
    'preset': preset,
    'followTheme': followTheme,
    'layout': layout,
    'imageSource': imageSource,
    'imageUrl': imageUrl,
    if (introText != null) 'introText': introText,
    'libraryImage': libraryImage.toMap(),
    'imageFit': imageFit,
    'radius': radius,
    'buttonStyle': buttonStyle,
    'showName': showName,
    'showIntro': showIntro,
    'showActions': showActions,
    'fields': orderedFields,
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
      actionIds: raw['actionIds'] is List
          ? (raw['actionIds'] as List)
                .whereType<String>()
                .where(
                  ['phone', 'map', 'line', 'instagram', 'facebook'].contains,
                )
                .toSet()
                .toList()
          : const ['phone', 'map', 'line', 'instagram', 'facebook'],
      actionLayout: choice('actionLayout', [
        'wrap',
        'threeColumns',
        'vertical',
      ], 'wrap'),
      actionPresentation: choice('actionPresentation', [
        'standard',
        'circle',
        'tile',
        'pill',
      ], 'standard'),
      photoShape: choice('photoShape', [
        'rounded',
        'circle',
        'square',
      ], 'rounded'),
      decoration: choice('decoration', ['none', 'leaf', 'paw', 'cat'], 'none'),
      phoneLabel: (raw['phoneLabel'] ?? '電話聯絡').toString().substring(
        0,
        (raw['phoneLabel'] ?? '電話聯絡').toString().length.clamp(0, 20),
      ),
      mapLabel: (raw['mapLabel'] ?? '查看地圖').toString(),
      lineLabel: (raw['lineLabel'] ?? '加入 LINE').toString(),
      sectionTitle: (raw['sectionTitle'] ?? '店家資訊').toString(),
      photoFraction:
          raw['photoFraction'] is num && (raw['photoFraction'] as num).isFinite
          ? (raw['photoFraction'] as num).toDouble().clamp(.2, .5)
          : .36,
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
      introText: raw['introText'] is String
          ? (raw['introText'] as String).substring(
              0,
              (raw['introText'] as String).length.clamp(0, 300),
            )
          : null,
      imageUrl: uri?.scheme == 'https' && uri!.host.isNotEmpty ? url : '',
      libraryImage: HomeCardImageSetting.fromMap(raw['libraryImage']),
      imageFit: choice('imageFit', ['cover', 'contain'], 'cover'),
      radius: r is num && r.isFinite ? r.toDouble().clamp(0, 32) : 20,
      buttonStyle: choice('buttonStyle', [
        'mixed',
        'light',
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
    this.layout, {
    this.imageSource = 'none',
    this.presentation = 'standard',
    this.actionLayout = 'threeColumns',
    this.buttonStyle = 'outlined',
    this.photoShape = 'rounded',
    this.decoration = 'none',
    this.showName = true,
    this.showIntro = true,
    this.radius = 20,
    this.photoFraction = .36,
  });
  final String id,
      label,
      layout,
      imageSource,
      presentation,
      actionLayout,
      buttonStyle,
      photoShape,
      decoration;
  final int accent, surface, text;
  final bool showName, showIntro;
  final double radius, photoFraction;
  String get previewAsset => 'assets/template_previews/footer_$id.png';

  (double, double) get previewCrop => switch (id) {
    'warm' => (.812, .941),
    'forest' => (.827, .935),
    'boutique' => (.879, .943),
    'peach' => (.785, .932),
    'blue' => (.839, .937),
    'natural' => (.869, .937),
    'panorama' => (.874, .949),
    'journey' => (.850, .949),
    'clear' => (.856, .943),
    'journal' => (.829, .947),
    _ => (.82, .94),
  };

  /// Only footer appearance. Keep the owner's delivery mode, uploads and labels.
  HomeShopInfoSetting apply(HomeShopInfoSetting current) => current.copyWith(
    enabled: true,
    preset: id,
    followTheme: false,
    layout: layout,
    imageSource: imageSource,
    actionPresentation: presentation,
    actionLayout: actionLayout,
    buttonStyle: buttonStyle,
    photoShape: photoShape,
    decoration: decoration,
    showName: showName,
    showIntro: showIntro,
    radius: radius,
    photoFraction: photoFraction,
    showActions: true,
    imageFit: 'cover',
    actionIds: const ['phone', 'map', 'line'],
  );
}

/// Complete appearance recipes; no business content or sample photos are imported.
const shopInfoPresets = [
  ShopInfoPreset(
    'warm',
    'A1 奶油暖橘',
    0xFFFF8B23,
    0xFFFFF8EF,
    0xFF56321F,
    'photoContact',
    imageSource: 'photo',
    buttonStyle: 'mixed',
    showName: false,
    showIntro: false,
  ),
  ShopInfoPreset(
    'forest',
    'A2 日系森林',
    0xFF657E6B,
    0xFFFCFCF8,
    0xFF34463B,
    'infoActions',
    presentation: 'circle',
    buttonStyle: 'filled',
    decoration: 'leaf',
    showName: false,
    showIntro: false,
    radius: 16,
  ),
  ShopInfoPreset(
    'boutique',
    'A3 精品旅宿',
    0xFFAC8B5B,
    0xFF342D26,
    0xFFFFF7EC,
    'brandColumns',
    presentation: 'circle',
    buttonStyle: 'mixed',
    radius: 0,
  ),
  ShopInfoPreset(
    'peach',
    'A4 蜜桃貓咪',
    0xFFD98478,
    0xFFFFF8F3,
    0xFF593C37,
    'photoDetails',
    imageSource: 'photo',
    presentation: 'pill',
    buttonStyle: 'mixed',
    photoShape: 'circle',
    decoration: 'paw',
    radius: 28,
  ),
  ShopInfoPreset(
    'blue',
    'A5 清爽導購',
    0xFF264C68,
    0xFF264C68,
    0xFFFFFFFF,
    'brandSplit',
    imageSource: 'logo',
    presentation: 'pill',
    buttonStyle: 'light',
    radius: 0,
  ),
  ShopInfoPreset(
    'natural',
    'B1 選房小幫手',
    0xFF56674E,
    0xFFF3F2E9,
    0xFF3D4638,
    'brandColumns',
    presentation: 'tile',
    decoration: 'leaf',
    radius: 0,
  ),
  ShopInfoPreset(
    'panorama',
    'B2 沉浸環境導覽',
    0xFF926B36,
    0xFFFFF9F1,
    0xFF47372A,
    'infoActions',
    imageSource: 'logo',
    presentation: 'tile',
    showIntro: false,
    radius: 16,
  ),
  ShopInfoPreset(
    'journey',
    'B3 入住旅程',
    0xFFFF8B35,
    0xFFFFFBF3,
    0xFF57391F,
    'photoThree',
    imageSource: 'photo',
    presentation: 'pill',
    actionLayout: 'vertical',
    buttonStyle: 'mixed',
    showName: false,
    showIntro: false,
    photoFraction: .32,
  ),
  ShopInfoPreset(
    'clear',
    'B4 透明房價',
    0xFF216692,
    0xFFF6FBFF,
    0xFF20485F,
    'photoRight',
    imageSource: 'photo',
    presentation: 'pill',
    radius: 18,
  ),
  ShopInfoPreset(
    'journal',
    'B5 品牌生活誌',
    0xFF7C372E,
    0xFFFFF9F5,
    0xFF633E38,
    'editorialPhoto',
    imageSource: 'photo',
    presentation: 'pill',
    decoration: 'cat',
    photoShape: 'square',
    radius: 0,
    photoFraction: .44,
  ),
];
