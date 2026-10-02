import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';

/// 新版前台底部導覽。正式頁與即時預覽共用這一個 renderer。
class ModernBottomNavigation extends StatelessWidget {
  const ModernBottomNavigation({
    super.key,
    required this.slots,
    required this.theme,
    required this.selectedId,
    required this.appearance,
    required this.surface,
    required this.onSelect,
  });

  static const double attachedHeight = 62;
  static const double pillHeight = 64;
  static const double minimalHeight = 54;
  static const double sideInset = 16;
  static const double floatBottomGap = 12;
  static const double menuButtonSize = 48;
  static const double menuGap = 8;

  final List<FrontendNavigationItem?> slots;
  final HomeThemeModel theme;
  final String selectedId;
  final String appearance;
  final String surface;
  final ValueChanged<FrontendNavigationItem> onSelect;

  static bool isFloating(String appearance) {
    return appearance == FrontendNavigationConfig.appearanceFloatingPill ||
        appearance == FrontendNavigationConfig.appearanceFloatingMinimal;
  }

  static double barHeightFor(String appearance) {
    switch (appearance) {
      case FrontendNavigationConfig.appearanceFloatingMinimal:
        return minimalHeight;
      case FrontendNavigationConfig.appearanceFloatingPill:
        return pillHeight;
      default:
        return attachedHeight;
    }
  }

  /// 底欄佔用的高度，含 SafeArea 與懸浮間距。
  static double slotHeight(String appearance, double safeBottom) {
    final double gap = isFloating(appearance) ? floatBottomGap : 0;
    return barHeightFor(appearance) + gap + safeBottom;
  }

  /// 店家選單按鈕距離螢幕底端的位置。
  static double menuBottom(String appearance, double safeBottom) {
    return slotHeight(appearance, safeBottom) + menuGap;
  }

  /// 內容要避開底欄與店家選單的底部留白。
  static double contentClearance(String appearance, double safeBottom) {
    return menuBottom(appearance, safeBottom) + menuButtonSize + 12;
  }

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final bool floating = isFloating(appearance);
    final double radius = appearance ==
            FrontendNavigationConfig.appearanceFloatingMinimal
        ? 18
        : (floating ? 28 : 0);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        floating ? sideInset : 0,
        0,
        floating ? sideInset : 0,
        (floating ? floatBottomGap : 0) + safeBottom,
      ),
      child: _BarSurface(
        theme: theme,
        surface: surface,
        height: barHeightFor(appearance),
        radius: radius,
        minimal: appearance ==
            FrontendNavigationConfig.appearanceFloatingMinimal,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < 5; i++)
              Expanded(
                child: _Slot(
                  item: i < slots.length ? slots[i] : null,
                  theme: theme,
                  surface: surface,
                  selected: i < slots.length &&
                      slots[i] != null &&
                      slots[i]!.id == selectedId,
                  emphasized: i == 2,
                  onSelect: onSelect,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarSurface extends StatelessWidget {
  const _BarSurface({
    required this.theme,
    required this.surface,
    required this.height,
    required this.radius,
    required this.minimal,
    required this.child,
  });

  final HomeThemeModel theme;
  final String surface;
  final double height;
  final double radius;
  final bool minimal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double opacity = switch (surface) {
      FrontendNavigationConfig.surfaceTranslucent => 0.76,
      FrontendNavigationConfig.surfaceTransparent => 0.08,
      _ => 0.98,
    };
    final double blur = switch (surface) {
      FrontendNavigationConfig.surfaceTranslucent => 8,
      _ => 0,
    };
    final Color fill = theme.cardColor.withValues(alpha: opacity);
    final BorderRadius shape = BorderRadius.circular(radius);
    final Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: Border.all(
          color: surface == FrontendNavigationConfig.surfaceTransparent
              ? theme.textColor.withValues(alpha: 0.28)
              : theme.cardBorderColor.withValues(alpha: 0.8),
        ),
        boxShadow: minimal
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: SizedBox(height: height, child: child),
    );
    return ClipRRect(
      borderRadius: shape,
      child: blur <= 0
          ? bar
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: bar,
            ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.item,
    required this.theme,
    required this.surface,
    required this.selected,
    required this.emphasized,
    required this.onSelect,
  });

  final FrontendNavigationItem? item;
  final HomeThemeModel theme;
  final String surface;
  final bool selected;
  final bool emphasized;
  final ValueChanged<FrontendNavigationItem> onSelect;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const SizedBox(height: 48);
    }
    final bool transparent =
        surface == FrontendNavigationConfig.surfaceTransparent;
    final Color ink = _inkColor(theme, transparent: transparent);
    final Color color = selected ? theme.primaryColor : ink;
    final double iconSize = emphasized ? 26 : 22;
    return Semantics(
      button: true,
      selected: selected,
      label: item!.label,
      child: InkWell(
        onTap: () => onSelect(item!),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? theme.primaryColor.withValues(
                          alpha: transparent ? 0.16 : 0.12,
                        )
                      : (transparent
                            ? ink.withValues(alpha: 0.08)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: emphasized ? 10 : 8,
                    vertical: emphasized ? 3 : 2,
                  ),
                  child: Icon(item!.icon, size: iconSize, color: color),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item!.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _inkColor(HomeThemeModel theme, {required bool transparent}) {
    if (!transparent) {
      return theme.textColor.withValues(alpha: 0.62);
    }
    final bool lightBackground = theme.backgroundColor.computeLuminance() > 0.55;
    final Color base = lightBackground ? const Color(0xFF1F2937) : Colors.white;
    return base.withValues(alpha: 0.88);
  }
}
