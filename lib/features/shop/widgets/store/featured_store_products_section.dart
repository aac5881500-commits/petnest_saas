// lib/features/shop/widgets/store/featured_store_products_section.dart
// 🛒 新版 Beta 首頁精選商品
// 功能：熱門房型之後顯示少量 featured 商品。模組未開、前台關閉或沒有商品時整區隱藏。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_price_view.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_promotion_badge.dart';
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
      builder:
          (
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
              stream: StoreProductService.instance.streamFeaturedProducts(
                shopId,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<StoreProductModel>> snapshot,
                  ) {
                    final List<StoreProductModel> products =
                        snapshot.data ?? const <StoreProductModel>[];
                    final Map<String, dynamic> storeSettings =
                        settingsSnapshot.data ?? const <String, dynamic>{};
                    if (storeSettings['showFeaturedProducts'] == false) {
                      return const SizedBox.shrink();
                    }
                    final int featuredCount = _featuredCount(storeSettings);
                    final bool hideOutOfStock =
                        storeSettings['hideOutOfStock'] == true;
                    final List<StoreProductModel> visible = products
                        .where((StoreProductModel item) {
                          if (!item.hasInventoryLink) {
                            return false;
                          }
                          return !hideOutOfStock ||
                              !StoreStockHelper.isOutOfStock(item);
                        })
                        .take(featuredCount)
                        .toList();
                    if (visible.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return StoreEnabledPromotionsBuilder(
                      shopId: shopId,
                      builder:
                          (
                            BuildContext context,
                            List<StorePromotionModel> promotions,
                          ) {
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
                                    height: 198,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: visible.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 7),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            return _FeaturedProductCard(
                                              product: visible[index],
                                              priced: StorePricingService
                                                  .instance
                                                  .quoteProduct(
                                                    product: visible[index],
                                                    promotions: promotions,
                                                  ),
                                              theme: theme,
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        StoreProductDetailPage(
                                                          shopId: shopId,
                                                          shop: shop,
                                                          productId:
                                                              visible[index].id,
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
          },
    );
  }

  int _featuredCount(Map<String, dynamic> settings) {
    final int count = settings['featuredCount'] is int
        ? settings['featuredCount'] as int
        : int.tryParse(settings['featuredCount']?.toString() ?? '') ?? 6;
    if (count == 4 || count == 8) {
      return count;
    }
    return 6;
  }

  void _openStore(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreHomePage(shopId: shopId, shop: shop, theme: theme),
      ),
    );
  }
}

class _FeaturedProductCard extends StatelessWidget {
  const _FeaturedProductCard({
    required this.product,
    required this.theme,
    required this.onTap,
    required this.priced,
  });

  final StoreProductModel product;
  final HomeThemeModel theme;
  final VoidCallback onTap;
  final StorePricedLine priced;

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
                      if (priced.showsPromotionOnProductImage)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: StorePromotionBadge(
                            line: priced,
                            color: theme.primaryColor,
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
                                '售罄',
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
                      StoreProductPriceView(
                        line: priced,
                        compact: true,
                        showBadge: priced.isBuyXGetYOffer,
                        color: theme.primaryColor,
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
