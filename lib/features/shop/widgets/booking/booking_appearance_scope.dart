import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// 只影響住宿預約工作區，未包裹的共用卡片維持原樣。
class BookingAppearanceScope extends InheritedWidget {
  const BookingAppearanceScope({
    super.key,
    required this.appearance,
    this.frontendTheme,
    required super.child,
  });
  final BookingPageAppearance appearance;
  final HomeThemeModel? frontendTheme;
  static HomeThemeModel? frontendOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BookingAppearanceScope>()
      ?.frontendTheme;
  static BookingPageAppearance of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BookingAppearanceScope>()
          ?.appearance ??
      const BookingPageAppearance();
  @override
  bool updateShouldNotify(BookingAppearanceScope oldWidget) =>
      oldWidget.appearance != appearance ||
      oldWidget.frontendTheme != frontendTheme;
}

BoxDecoration bookingCardDecoration(String style, HomeThemeModel theme) {
  final line = theme.cardBorderColor;
  return switch (style) {
    'cream' || 'house' => const BoxDecoration(),
    'minimal' => BoxDecoration(
      color: theme.cardColor,
      border: Border(bottom: BorderSide(color: line)),
    ),
    'boutique' => BoxDecoration(
      color: theme.cardColor,
      border: Border(left: BorderSide(color: theme.primaryColor, width: 3)),
      borderRadius: BorderRadius.circular(4),
    ),
    'soft' => BoxDecoration(
      color: Color.alphaBlend(
        theme.primaryColor.withValues(alpha: 0.035),
        theme.cardColor,
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: theme.textColor.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    'compact' => BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    _ => BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
  };
}

EdgeInsets bookingCardPadding(String style) => switch (style) {
  'cream' || 'house' => const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
  'minimal' => const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
  'boutique' => const EdgeInsets.all(22),
  'soft' => const EdgeInsets.all(20),
  'compact' => const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
  _ => const EdgeInsets.all(14),
};
