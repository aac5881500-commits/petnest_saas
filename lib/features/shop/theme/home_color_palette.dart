import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class HomeColorSwatch {
  const HomeColorSwatch(this.name, this.argb);

  final String name;
  final int argb;

  String get hex => HomeColorPalette.hexOf(argb);
}

class HomeColorPreset {
  const HomeColorPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.background,
    required this.card,
    required this.border,
    required this.primary,
    required this.text,
    required this.secondary,
  });

  final String id;
  final String name;
  final String description;
  final int background;
  final int card;
  final int border;
  final int primary;
  final int text;
  final int secondary;

  List<int> get preview => <int>[background, card, primary, text, secondary];

  bool matches(HomeThemeModel theme) {
    return theme.backgroundColorValue == background &&
        theme.cardColorValue == card &&
        theme.cardBorderColorValue == border &&
        theme.primaryColorValue == primary &&
        theme.textColorValue == text &&
        theme.secondaryTextColorValue == secondary &&
        theme.buttonFollowsPrimary &&
        theme.buttonTextMode == 'auto';
  }

  HomeThemeModel apply(HomeThemeModel current) {
    return current.copyWith(
      backgroundColorValue: background,
      cardColorValue: card,
      cardBorderColorValue: border,
      primaryColorValue: primary,
      textColorValue: text,
      secondaryTextColorValue: secondary,
      buttonBackgroundColorValue: null,
      buttonTextMode: 'auto',
      buttonTextColorValue: null,
    );
  }
}

class HomeColorPalette {
  static const List<HomeColorSwatch> surfaces = <HomeColorSwatch>[
    HomeColorSwatch('純白', 0xFFFFFFFF),
    HomeColorSwatch('暖白', 0xFFFFFBF7),
    HomeColorSwatch('奶油', 0xFFFFF5E8),
    HomeColorSwatch('淡粉', 0xFFFFF4F6),
    HomeColorSwatch('淡橘', 0xFFFFF3E8),
    HomeColorSwatch('淡藍', 0xFFF3F8FC),
    HomeColorSwatch('淡紫', 0xFFF7F4FB),
    HomeColorSwatch('淡綠', 0xFFF3F7F4),
    HomeColorSwatch('淺灰', 0xFFF5F5F5),
    HomeColorSwatch('淡咖啡', 0xFFF8F1EA),
    HomeColorSwatch('霧灰', 0xFFF7F7F8),
    HomeColorSwatch('象牙', 0xFFFFFCF8),
  ];

  static const List<HomeColorSwatch> accents = <HomeColorSwatch>[
    HomeColorSwatch('暖橘', 0xFFFF8A00),
    HomeColorSwatch('珊瑚紅', 0xFFE86A5A),
    HomeColorSwatch('玫瑰粉', 0xFFE06B84),
    HomeColorSwatch('湖水藍', 0xFF3AA0B5),
    HomeColorSwatch('靛藍', 0xFF3B5BDB),
    HomeColorSwatch('葡萄紫', 0xFF8B5FBF),
    HomeColorSwatch('鼠尾草綠', 0xFF6B8F71),
    HomeColorSwatch('深綠', 0xFF2F6B4F),
    HomeColorSwatch('焦糖', 0xFFC4843A),
    HomeColorSwatch('咖啡', 0xFF8A5A3B),
    HomeColorSwatch('深灰', 0xFF3F3F46),
    HomeColorSwatch('品牌藍', 0xFF1B4F8A),
  ];

  static const List<HomeColorSwatch> inks = <HomeColorSwatch>[
    HomeColorSwatch('深咖啡', 0xFF3A2A20),
    HomeColorSwatch('炭黑', 0xFF1C1917),
    HomeColorSwatch('深灰', 0xFF3F3F46),
    HomeColorSwatch('藍黑', 0xFF1E3348),
    HomeColorSwatch('深綠', 0xFF24362A),
    HomeColorSwatch('深紫', 0xFF32243F),
    HomeColorSwatch('白色', 0xFFFFFFFF),
    HomeColorSwatch('暖白', 0xFFF5F0EA),
  ];

  static const List<HomeColorPreset> presets = <HomeColorPreset>[
    HomeColorPreset(
      id: 'warmCream',
      name: '暖橘奶油',
      description: '溫暖、明亮，適合寵物住宿',
      background: 0xFFFFF8F3,
      card: 0xFFFFFFFF,
      border: 0xFFFFD9B3,
      primary: 0xFFFF8A00,
      text: 0xFF3A2A20,
      secondary: 0xFF8A7368,
    ),
    HomeColorPreset(
      id: 'sakura',
      name: '櫻花粉',
      description: '柔和粉調，感覺親切',
      background: 0xFFFFF6F7,
      card: 0xFFFFFFFF,
      border: 0xFFF8D0D6,
      primary: 0xFFE06B84,
      text: 0xFF4A2C32,
      secondary: 0xFF8D6A72,
    ),
    HomeColorPreset(
      id: 'freshBlue',
      name: '清新藍',
      description: '乾淨、清爽的藍色',
      background: 0xFFF4F8FC,
      card: 0xFFFFFFFF,
      border: 0xFFD3E4F5,
      primary: 0xFF3B82C4,
      text: 0xFF1E3348,
      secondary: 0xFF5E7388,
    ),
    HomeColorPreset(
      id: 'sage',
      name: '鼠尾草綠',
      description: '安靜的綠，適合放鬆',
      background: 0xFFF4F7F4,
      card: 0xFFFFFFFF,
      border: 0xFFD5E3D8,
      primary: 0xFF6B8F71,
      text: 0xFF24362A,
      secondary: 0xFF5E7264,
    ),
    HomeColorPreset(
      id: 'grape',
      name: '葡萄紫',
      description: '柔和紫調，帶一點精緻',
      background: 0xFFF7F4FB,
      card: 0xFFFFFFFF,
      border: 0xFFE4D7F2,
      primary: 0xFF8B5FBF,
      text: 0xFF32243F,
      secondary: 0xFF6E5C82,
    ),
    HomeColorPreset(
      id: 'milkTea',
      name: '咖啡奶茶',
      description: '奶茶色，溫潤耐看',
      background: 0xFFFBF6F0,
      card: 0xFFFFFCF8,
      border: 0xFFE6D3C2,
      primary: 0xFF9B7653,
      text: 0xFF3E2C22,
      secondary: 0xFF7A6558,
    ),
    HomeColorPreset(
      id: 'minimal',
      name: '極簡灰白',
      description: '留白多、線條清楚',
      background: 0xFFF7F7F8,
      card: 0xFFFFFFFF,
      border: 0xFFE4E4E7,
      primary: 0xFF3F3F46,
      text: 0xFF18181B,
      secondary: 0xFF71717A,
    ),
    HomeColorPreset(
      id: 'dark',
      name: '深色質感',
      description: '深底淺字，夜間也清楚',
      background: 0xFF1C1917,
      card: 0xFF292524,
      border: 0xFF44403C,
      primary: 0xFFE8A87C,
      text: 0xFFF5F0EA,
      secondary: 0xFFC4B8AE,
    ),
  ];

  static HomeColorPreset? matching(HomeThemeModel theme) {
    for (final HomeColorPreset preset in presets) {
      if (preset.matches(theme)) {
        return preset;
      }
    }
    return null;
  }

  static String hexOf(int argb, {bool forceAlpha = false}) {
    final int alpha = (argb >> 24) & 0xFF;
    if (!forceAlpha && alpha == 0xFF) {
      return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
    return '#${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static int withAlpha(int argb, double opacity) {
    final int alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    return (alpha << 24) | (argb & 0x00FFFFFF);
  }

  static double alphaOf(int argb) => ((argb >> 24) & 0xFF) / 255;

  /// 回傳 null 代表格式不正確。
  static int? tryParseHex(String raw, {required bool allowAlpha}) {
    String text = raw.trim();
    if (text.startsWith('#')) {
      text = text.substring(1);
    }
    if (text.startsWith('0x') || text.startsWith('0X')) {
      text = text.substring(2);
    }
    final bool ok = allowAlpha
        ? text.length == 6 || text.length == 8
        : text.length == 6;
    if (!ok || int.tryParse(text, radix: 16) == null) {
      return null;
    }
    if (text.length == 6) {
      text = 'FF$text';
    }
    return int.parse(text, radix: 16);
  }
}

class HomeColorContrast {
  static double ratio(Color foreground, Color background) {
    final double lighter = _lum(foreground) > _lum(background)
        ? _lum(foreground)
        : _lum(background);
    final double darker = _lum(foreground) > _lum(background)
        ? _lum(background)
        : _lum(foreground);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _lum(Color color) => color.computeLuminance();

  static Color readableInk(Color background) {
    return background.computeLuminance() > 0.45
        ? const Color(0xFF3A2A20)
        : const Color(0xFFFFFFFF);
  }

  static bool pageNeedsAttention(HomeThemeModel theme) {
    final Color text = theme.textColor;
    final Color buttonInk = theme.buttonForegroundColor;
    final Color navSurface = Color.alphaBlend(
      theme.primaryColor.withValues(alpha: 0.12),
      theme.cardColor,
    );
    return ratio(text, theme.backgroundColor) < 4.5 ||
        ratio(text, theme.cardColor) < 4.5 ||
        ratio(buttonInk, theme.buttonBackgroundColor) < 3 ||
        ratio(theme.primaryColor, navSurface) < 2;
  }
}
