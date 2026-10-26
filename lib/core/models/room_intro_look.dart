// 功能：排版以外的房型介紹外觀；切換結構不重設裝飾設定。
class RoomIntroLook {
  const RoomIntroLook({
    this.textSize = 'standard',
    this.fontFamily = '',
    this.align = 'start',
    this.density = 'standard',
    this.border = true,
    this.shadow = false,
    this.radius = 18,
    this.showDimensions = true,
    this.background = 'theme',
    this.backgroundColor = 0xfff5f3ef,
    this.backgroundAssetId = '',
  });
  static const fonts = <String, String>{
    '': '跟隨店家主題',
    'jfOpenHuninn': '粉圓體',
    'NotoSansTC': '思源黑體 TC',
    'NotoSerifTC': '思源宋體 TC',
    'ChironSungHK': '昭源宋體',
  };
  String? get appliedFontFamily =>
      fontFamily.isNotEmpty && fonts.containsKey(fontFamily)
      ? fontFamily
      : null;
  final String fontFamily,
      textSize,
      align,
      density,
      background,
      backgroundAssetId;
  final bool border, shadow, showDimensions;
  final double radius;
  final int backgroundColor;
  double get scale => textSize == 'large'
      ? 1.15
      : textSize == 'small'
      ? .9
      : 1;
  double get padding => density == 'compact'
      ? 8
      : density == 'wide'
      ? 20
      : 12;
  RoomIntroLook copyWith({
    String? fontFamily,
    String? textSize,
    String? align,
    String? density,
    bool? border,
    bool? shadow,
    double? radius,
    bool? showDimensions,
    String? background,
    int? backgroundColor,
    String? backgroundAssetId,
  }) => RoomIntroLook(
    fontFamily: fontFamily ?? this.fontFamily,
    textSize: textSize ?? this.textSize,
    align: align ?? this.align,
    density: density ?? this.density,
    border: border ?? this.border,
    shadow: shadow ?? this.shadow,
    radius: radius ?? this.radius,
    showDimensions: showDimensions ?? this.showDimensions,
    background: background ?? this.background,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    backgroundAssetId: backgroundAssetId ?? this.backgroundAssetId,
  );
  Map<String, dynamic> toMap() => {
    'fontFamily': appliedFontFamily ?? '',
    'textSize': textSize,
    'align': align,
    'density': density,
    'border': border,
    'shadow': shadow,
    'radius': radius,
    'showDimensions': showDimensions,
    'background': background,
    'backgroundColor': backgroundColor,
    'backgroundAssetId': backgroundAssetId,
  };
  static RoomIntroLook fromMap(Object? raw) {
    final m = raw is Map ? raw : const {};
    String choice(String key, List<String> values, String fallback) =>
        values.contains(m[key]) ? m[key] as String : fallback;
    final radius = num.tryParse('${m['radius']}');
    final color = m['backgroundColor'];
    final id = '${m['backgroundAssetId'] ?? ''}'.trim();
    return RoomIntroLook(
      fontFamily: choice('fontFamily', fonts.keys.toList(), ''),
      textSize: choice('textSize', ['small', 'standard', 'large'], 'standard'),
      align: choice('align', ['start', 'center'], 'start'),
      density: choice('density', ['compact', 'standard', 'wide'], 'standard'),
      border: m['border'] != false,
      shadow: m['shadow'] == true,
      radius: radius != null && radius.isFinite
          ? radius.clamp(0, 32).toDouble()
          : 18,
      showDimensions: m['showDimensions'] != false,
      background: choice('background', ['theme', 'color', 'library'], 'theme'),
      backgroundColor: color is int && color >= 0 && color <= 0xffffffff
          ? color
          : 0xfff5f3ef,
      backgroundAssetId: id.length <= 128 && !id.contains('/') ? id : '',
    );
  }
}
