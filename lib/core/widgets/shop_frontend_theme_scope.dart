// 單一上層監聽 shops/{shopId}，解析前台外觀後往下傳。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopFrontendThemeScope extends StatelessWidget {
  const ShopFrontendThemeScope({
    super.key,
    required this.shopId,
    required this.builder,
  });

  final String shopId;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final String id = shopId.trim();
    if (id.isEmpty) {
      return ShopFrontendThemeInherited(
        theme: ShopFrontendTheme.fallback,
        child: Builder(builder: builder),
      );
    }
    return StreamBuilder<Map<String, dynamic>?>(
      key: ValueKey<String>(id),
      stream: ShopService.instance.streamShop(id),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot,
          ) {
            if (snapshot.hasError) {
              if (kDebugMode) {
                debugPrint('SHOP_FRONTEND_THEME_SCOPE: ${snapshot.error}');
              }
              return ShopFrontendThemeInherited(
                theme: ShopFrontendTheme.fallback,
                child: Builder(builder: builder),
              );
            }
            return ShopFrontendThemeInherited(
              theme: ShopFrontendTheme.fromShop(snapshot.data),
              child: Builder(builder: builder),
            );
          },
    );
  }
}
