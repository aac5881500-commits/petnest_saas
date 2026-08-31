// lib/features/shop/widgets/store/storefront_theme.dart
// 🛒 商城前台外觀：只影響賣場，不改旅館主題

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';

class StorefrontTheme extends StatelessWidget {
  const StorefrontTheme({
    super.key,
    required this.shopId,
    required this.shopTheme,
    required this.builder,
  });

  final String shopId;
  final HomeThemeModel shopTheme;
  final Widget Function(
    BuildContext context,
    HomeThemeModel theme,
    StoreHomeDisplaySettings home,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        final StoreHomeDisplaySettings home =
            StoreHomeDisplaySettings.fromMap(
          snapshot.data ?? const <String, dynamic>{},
        );
        return builder(context, home.resolveTheme(shopTheme), home);
      },
    );
  }
}
