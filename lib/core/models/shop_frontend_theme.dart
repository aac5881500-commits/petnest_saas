// 檔案名稱：lib/core/models/shop_frontend_theme.dart
// 功能說明：客戶前台主題：沿用 shops/{shopId}.homeAppearance，與首頁同一份資料。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';

class ShopFrontendTheme {
  const ShopFrontendTheme({
    required this.home,
    required this.primaryColor,
    required this.secondaryColor,
    required this.pageBackgroundColor,
    required this.cardColor,
    required this.titleColor,
    required this.bodyTextColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.buttonColor,
    required this.onPrimaryColor,
    required this.primarySoft,
    required this.disabledColor,
  });

  final HomeThemeModel home;

  final Color primaryColor;
  final Color secondaryColor;
  final Color pageBackgroundColor;
  final Color cardColor;
  final Color titleColor;
  final Color bodyTextColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color buttonColor;
  final Color onPrimaryColor;
  final Color primarySoft;
  final Color disabledColor;

  static const Color successColor = Color(0xFF5A9A6A);
  static const Color successSoft = Color(0xFFEAF6EC);
  static const Color warningColor = Color(0xFFE08A3A);
  static const Color warningSoft = Color(0xFFFFF3E6);
  static const Color errorColor = Color(0xFFC45C5C);
  static const Color errorSoft = Color(0xFFFBECEC);

  static final ShopFrontendTheme fallback = ShopFrontendTheme.fromHome(
    HomeThemeModel.modernDefault,
  );

  Color get background => pageBackgroundColor;
  Color get card => cardColor;
  Color get border => borderColor;
  Color get primary => primaryColor;
  Color get text => bodyTextColor;
  Color get muted => subtitleColor;
  Color get success => successColor;
  Color get danger => errorColor;
  Color get warning => warningColor;
  Color get iconSoft => primarySoft;
  Color get dangerSoft => errorSoft;

  factory ShopFrontendTheme.fromHome(HomeThemeModel home) {
    final Color primary = home.primaryColor;
    final Color background = home.backgroundColor;
    final Color card = home.cardColor;
    final Color title = home.textColor;
    final Color onPrimary = contrastOn(primary);
    final Color subtitle = _readableMix(title, background, 0.42);
    final Color border = _ensureBorder(home.cardBorderColor, card, title);
    final Color secondary = Color.lerp(primary, title, 0.28) ?? title;
    return ShopFrontendTheme(
      home: home,
      primaryColor: primary,
      secondaryColor: secondary,
      pageBackgroundColor: background,
      cardColor: card,
      titleColor: title,
      bodyTextColor: title,
      subtitleColor: subtitle,
      borderColor: border,
      buttonColor: primary,
      onPrimaryColor: onPrimary,
      primarySoft: primary.withValues(alpha: 0.14),
      disabledColor:
          Color.lerp(title, background, 0.62) ?? const Color(0xFFB8A99C),
    );
  }

  factory ShopFrontendTheme.fromShop(Map<String, dynamic>? shop) {
    try {
      return ShopFrontendTheme.fromHome(
        HomeBannerService.instance.themeFromShop(shop),
      );
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('SHOP_FRONTEND_THEME: $error');
        debugPrint('$stack');
      }
      return fallback;
    }
  }

  static Color contrastOn(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF3A2A20);
  }

  static Color _readableMix(Color foreground, Color background, double amount) {
    final Color mixed =
        Color.lerp(foreground, background, amount) ?? foreground;
    final int fgLum = mixed.computeLuminance() < background.computeLuminance()
        ? 1
        : 0;
    if ((mixed.computeLuminance() - background.computeLuminance()).abs() <
        0.18) {
      return fgLum == 1
          ? Color.lerp(foreground, Colors.black, 0.15) ?? foreground
          : Color.lerp(foreground, Colors.white, 0.12) ?? foreground;
    }
    return mixed;
  }

  static Color _ensureBorder(Color border, Color card, Color text) {
    if ((border.computeLuminance() - card.computeLuminance()).abs() < 0.04) {
      return Color.lerp(card, text, 0.12) ?? border;
    }
    return border;
  }

  static ShopFrontendTheme of(BuildContext context) {
    final ShopFrontendThemeInherited? inherited = context
        .dependOnInheritedWidgetOfExactType<ShopFrontendThemeInherited>();
    return inherited?.theme ?? fallback;
  }

  static ShopFrontendTheme maybeOf(BuildContext context) {
    return of(context);
  }

  LinearGradient get heroGradient {
    return LinearGradient(
      colors: <Color>[
        primaryColor,
        Color.lerp(primaryColor, secondaryColor, 0.45) ?? primaryColor,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class ShopFrontendThemeInherited extends InheritedWidget {
  const ShopFrontendThemeInherited({
    super.key,
    required this.theme,
    required super.child,
  });

  final ShopFrontendTheme theme;

  @override
  bool updateShouldNotify(ShopFrontendThemeInherited oldWidget) {
    return oldWidget.theme.primaryColor != theme.primaryColor ||
        oldWidget.theme.pageBackgroundColor != theme.pageBackgroundColor ||
        oldWidget.theme.cardColor != theme.cardColor ||
        oldWidget.theme.titleColor != theme.titleColor ||
        oldWidget.theme.borderColor != theme.borderColor;
  }
}
