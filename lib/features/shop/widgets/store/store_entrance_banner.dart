// lib/features/shop/widgets/store/store_entrance_banner.dart
// 🛒 新版 Beta 首頁賣場入口 Banner
// 功能：熱門房型／精選商品之後導向寵物賣場。文字吃外觀設定，顏色吃 HomeTheme。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_home_page.dart';

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
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!StorefrontAccess.isStorefrontOpen(
          shop: shop,
          settings: snapshot.data,
        )) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Material(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openStore(context),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorderColor),
                ),
                child: SizedBox(
                  height: 108,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                setting.storeBannerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  setting.storeBannerSubtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textColor.withValues(
                                      alpha: 0.68,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    setting.storeBannerButtonText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: theme.cardColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 108,
                        height: double.infinity,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(15),
                          ),
                          child: _buildImage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage() {
    final String imageUrl = _resolveImageUrl();
    if (imageUrl.isEmpty) {
      return ColoredBox(
        color: theme.primaryColor.withValues(alpha: 0.12),
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 36,
          color: theme.primaryColor,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return ColoredBox(
          color: theme.primaryColor.withValues(alpha: 0.12),
          child: Icon(
            Icons.shopping_bag_outlined,
            size: 36,
            color: theme.primaryColor,
          ),
        );
      },
    );
  }

  String _resolveImageUrl() {
    if (setting.storeBannerImageUrl.isNotEmpty) {
      return setting.storeBannerImageUrl;
    }

    final Object? rawBanners = shop['banners'];
    if (rawBanners is List) {
      for (final Object? item in rawBanners) {
        if (item is! Map) {
          continue;
        }
        final bool isActive = item['isActive'] != false;
        final String imageUrl = (item['imageUrl'] ?? '').toString().trim();
        if (isActive && imageUrl.isNotEmpty) {
          return imageUrl;
        }
      }
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
        builder: (_) => StoreHomePage(
          shopId: shopId,
          shop: shop,
          theme: theme,
        ),
      ),
    );
  }
}
