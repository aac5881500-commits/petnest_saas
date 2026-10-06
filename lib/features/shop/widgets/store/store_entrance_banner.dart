// 檔案名稱：lib/features/shop/widgets/store/store_entrance_banner.dart
// 功能說明：新版 Beta 首頁賣場入口：是否顯示走賣場模組；外觀走 homeAppearance。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
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

            void openStore() => _openStore(context);
            if (setting.storeEntryLayout == ModernStoreEntryLayouts.showcase) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _StoreShowcaseEntrance(
                  shopId: shopId,
                  theme: theme,
                  setting: setting,
                  fallbackImageUrl: _fallbackImageUrl(),
                  onTap: openStore,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: ModernHomeStoreCard(
                theme: theme,
                setting: setting,
                fallbackImageUrl: _fallbackImageUrl(),
                onTap: openStore,
                height:
                    setting.storeEntryLayout == ModernStoreEntryLayouts.brand
                    ? 210
                    : 168,
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

class _StoreShowcaseEntrance extends StatelessWidget {
  const _StoreShowcaseEntrance({
    required this.shopId,
    required this.theme,
    required this.setting,
    required this.fallbackImageUrl,
    required this.onTap,
  });

  final String shopId;
  final HomeThemeModel theme;
  final ModernStoreHomeSetting setting;
  final String fallbackImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoreProductModel>>(
      stream: StoreProductService.instance.streamFeaturedProducts(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<StoreProductModel>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final List<String> urls =
                (snapshot.data ?? const <StoreProductModel>[])
                    .where((StoreProductModel item) => item.hasInventoryLink)
                    .map((StoreProductModel item) => item.imageUrl)
                    .where((String url) => url.trim().isNotEmpty)
                    .take(3)
                    .toList();
            if (urls.isEmpty) {
              return ModernHomeStoreCard(
                theme: theme,
                setting: setting.copyWith(
                  storeEntryLayout: ModernStoreEntryLayouts.brand,
                ),
                fallbackImageUrl: fallbackImageUrl,
                onTap: onTap,
                height: 210,
              );
            }
            return ModernHomeStoreCard(
              theme: theme,
              setting: setting,
              fallbackImageUrl: fallbackImageUrl,
              showcaseImageUrls: urls,
              onTap: onTap,
            );
          },
    );
  }
}
