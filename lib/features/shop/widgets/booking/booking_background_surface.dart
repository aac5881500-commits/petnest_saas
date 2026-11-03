import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import '../shop_app_backdrop.dart';

/// 同時適用正式頁的固定高度與設定預覽的自然高度。
class BookingBackgroundSurface extends StatelessWidget {
  const BookingBackgroundSurface({
    super.key,
    required this.theme,
    required this.child,
  });
  final HomeThemeModel theme;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: ShopAppBackdrop(theme: theme)),
      child,
    ],
  );
}
