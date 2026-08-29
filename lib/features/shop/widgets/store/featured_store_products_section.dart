// lib/features/shop/widgets/store/featured_store_products_section.dart
// 🛒 新版 Beta 首頁精選商品
// 功能：熱門房型之後顯示少量 featured 商品。模組未開、前台關閉或沒有商品時整區隱藏。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_home_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_product_detail_page.dart';

class FeaturedStoreProductsSection extends StatelessWidget {
  const FeaturedStoreProductsSection({
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
    if (!setting.showFeaturedProducts ||
        !StorefrontAccess.isModuleEnabled(shop)) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> settingsSnapshot,
      ) {
        if (!StorefrontAccess.isStorefrontOpen(
          shop: shop,
          settings: settingsSnapshot.data,
        )) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<List<StoreProductModel>>(
          stream: StoreProductService.instance.streamFeaturedProducts(shopId),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<StoreProductModel>> snapshot,
          ) {
            final List<StoreProductModel> products =
                snapshot.data ?? const <StoreProductModel>[];
            if (products.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          setting.featuredTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openStore(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '查看全部',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryColor,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: theme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 176,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 7),
                      itemBuilder: (BuildContext context, int index) {
                        return _FeaturedProductCard(
                          product: products[index],
                          theme: theme,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => StoreProductDetailPage(
                                  shopId: shopId,
                                  shop: shop,
                                  productId: products[index].id,
                                  theme: theme,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

class _FeaturedProductCard extends StatelessWidget {
  const _FeaturedProductCard({
    required this.product,
    required this.theme,
    required this.onTap,
  });

  final StoreProductModel product;
  final HomeThemeModel theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool outOfStock = StoreStockHelper.isOutOfStock(product);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 124,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 108,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(
                        color: theme.primaryColor.withValues(alpha: 0.08),
                        child: product.imageUrl.isEmpty
                            ? Icon(
                                Icons.shopping_bag_outlined,
                                size: 32,
                                color: theme.primaryColor,
                              )
                            : Padding(
                                padding: const EdgeInsets.all(6),
                                child: Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) {
                                    return Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 32,
                                      color: theme.primaryColor,
                                    );
                                  },
                                ),
                              ),
                      ),
                      if (outOfStock)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: theme.primaryColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                '缺貨',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'NT\$${product.price}',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
