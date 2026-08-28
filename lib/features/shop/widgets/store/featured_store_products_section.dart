// lib/features/shop/widgets/store/featured_store_products_section.dart
// 🛒 首頁精選商品
// 功能：熱門房型之後顯示少量 featured 商品。模組未開或沒有上架商品時整區隱藏。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_home_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_product_detail_page.dart';

class FeaturedStoreProductsSection extends StatelessWidget {
  const FeaturedStoreProductsSection({
    super.key,
    required this.shopId,
    required this.shop,
    required this.theme,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    if (!StorefrontAccess.isModuleEnabled(shop)) {
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
                        Icons.storefront_outlined,
                        size: 16,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '精選商品',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StoreHomePage(
                                shopId: shopId,
                                shop: shop,
                                theme: theme,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          '查看更多',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final StoreProductModel product = products[index];
                        return SizedBox(
                          width: 118,
                          child: Material(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StoreProductDetailPage(
                                      shopId: shopId,
                                      shop: shop,
                                      productId: product.id,
                                      theme: theme,
                                    ),
                                  ),
                                );
                              },
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.cardBorderColor,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(13),
                                      ),
                                      child: SizedBox(
                                        height: 96,
                                        width: double.infinity,
                                        child: product.imageUrl.isEmpty
                                            ? ColoredBox(
                                                color: theme.primaryColor
                                                    .withValues(alpha: 0.08),
                                                child: Icon(
                                                  Icons.shopping_bag_outlined,
                                                  color: theme.primaryColor,
                                                ),
                                              )
                                            : Image.network(
                                                product.imageUrl,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        0,
                                      ),
                                      child: Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: theme.textColor,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        2,
                                        8,
                                        8,
                                      ),
                                      child: Text(
                                        'NT\$ ${product.price}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
}
