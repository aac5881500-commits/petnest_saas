// lib/features/shop/widgets/store/store_entrance_banner.dart
// 🛒 新版 Beta 首頁賣場入口：是否顯示走賣場模組；外觀走 homeAppearance。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_home_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_store_card.dart';

class StoreEntranceBanner extends StatelessWidget {
  const StoreEntranceBanner({
    super.key,
    required this.shopId,
    required this.shop,
    required this.theme,
    required this.setting,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;
  final ModernStoreHomeSetting setting;

  @override
  Widget build(BuildContext context) {
    if (!setting.showStoreBanner || !StorefrontAccess.isModuleEnabled(shop)) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(shopId),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
            if (!StorefrontAccess.isStorefrontOpen(
              shop: shop,
              settings: snapshot.data,
            )) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: ModernHomeStoreCard(
                theme: theme,
                setting: setting,
                fallbackImageUrl: _fallbackImageUrl(),
                onTap: () => _openStore(context),
              ),
            );
          },
    );
  }

  String _fallbackImageUrl() {
    if (setting.storeBannerImageUrl.trim().isNotEmpty) {
      return '';
    }
    final String coverUrl = (shop['coverUrl'] ?? '').toString().trim();
    if (coverUrl.isNotEmpty) {
      return coverUrl;
    }
    return (shop['logoUrl'] ?? '').toString().trim();
  }

  void _openStore(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreHomePage(shopId: shopId, shop: shop, theme: theme),
      ),
    );
  }
}
