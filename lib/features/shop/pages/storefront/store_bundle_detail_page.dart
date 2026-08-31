// lib/features/shop/pages/storefront/store_bundle_detail_page.dart
// 🛒 套裝優惠內容與加入購物車

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_cart_service.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_cart_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_availability_view.dart';
import 'package:petnest_saas/features/shop/widgets/store/storefront_theme.dart';

class StoreBundleDetailPage extends StatefulWidget {
  const StoreBundleDetailPage({
    super.key,
    required this.shopId,
    required this.shop,
    required this.promotion,
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final StorePromotionModel promotion;
  final HomeThemeModel theme;

  @override
  State<StoreBundleDetailPage> createState() => _StoreBundleDetailPageState();
}

class _StoreBundleDetailPageState extends State<StoreBundleDetailPage> {
  int _sets = 1;

  Future<void> _addToCart(int maxSets) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入')),
      );
      return;
    }
    try {
      await StoreCartService.instance.addBundle(
        shopId: widget.shopId,
        bundlePromotionId: widget.promotion.id,
        quantity: _sets.clamp(1, maxSets < 1 ? 1 : maxSets),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已加入購物車'),
          action: SnackBarAction(
            label: '查看購物車',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => StoreCartPage(
                    shopId: widget.shopId,
                    shop: widget.shop,
                    theme: widget.theme,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StorefrontTheme(
      shopId: widget.shopId,
      shopTheme: widget.theme,
      builder: (BuildContext context, HomeThemeModel theme, _) {
    return StreamBuilder<List<StoreProductModel>>(
      stream: StoreProductService.instance.streamEnabledProducts(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<StoreProductModel>> snapshot,
      ) {
        final List<StoreProductModel> products =
            snapshot.data ?? const <StoreProductModel>[];
        final int maxSets = StorePricingService.instance.maxBundleSets(
          promotion: widget.promotion,
          products: products,
        );
        final bool soldOut = maxSets < 1;
        final int sets = soldOut ? 1 : _sets.clamp(1, maxSets);
        final StoreBundleQuote quote = StorePricingService.instance.quoteBundle(
          promotion: widget.promotion,
          sets: sets,
          products: products,
        );
        return StreamBuilder<Map<String, dynamic>>(
          stream: StoreSettingsService.instance.streamSettings(widget.shopId),
          builder: (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>> settingsSnap,
          ) {
            final bool showStock =
                (settingsSnap.data ?? const <String, dynamic>{})
                    ['showStockToCustomer'] !=
                false;
            return Scaffold(
              backgroundColor: theme.backgroundColor,
              appBar: AppBar(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textColor,
                title: const Text('套裝優惠'),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  Text(
                    widget.promotion.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.promotion.description.trim().isEmpty
                        ? '內含 ${widget.promotion.bundlePieceCount} 件商品'
                        : widget.promotion.description,
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '套裝價 NT\$${quote.finalTotal}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                  if (quote.originalTotal > quote.finalTotal)
                    Text(
                      '原價 NT\$${quote.originalTotal}　現省 NT\$${quote.saved}',
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.62),
                      ),
                    ),
                  if (soldOut)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '售罄',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    '套裝包含',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.promotion.bundleItems.map((StoreBundleItem item) {
                    StoreProductModel? product;
                    for (final StoreProductModel candidate in products) {
                      if (candidate.id == item.productId) {
                        product = candidate;
                        break;
                      }
                    }
                    return Card(
                      child: ListTile(
                        leading: (product?.imageUrl ?? '').isEmpty
                            ? const Icon(Icons.shopping_bag_outlined)
                            : Image.network(
                                product!.imageUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                        title: Text(product?.name ?? '商品'),
                        subtitle: product == null
                            ? const Text('商品已下架')
                            : StoreAvailabilityView(
                                product: product,
                                showStockToCustomer: showStock,
                                compact: true,
                              ),
                        trailing: Text('×${item.quantity}'),
                      ),
                    );
                  }),
                  if (!soldOut) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      '購買組數',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: sets > 1
                              ? () => setState(() => _sets = sets - 1)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Text('$sets', style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        )),
                        IconButton(
                          onPressed: sets < maxSets
                              ? () => setState(() => _sets = sets + 1)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              bottomNavigationBar: Material(
                color: theme.cardColor,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: FilledButton(
                      onPressed: soldOut ? null : () => _addToCart(maxSets),
                      child: Text(soldOut ? '目前缺貨' : '加入購物車'),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
      },
    );
  }
}
