// 檔案名稱：lib/features/shop/pages/storefront/store_cart_page.dart
// 功能說明：每店獨立購物車。不扣除 currentStock。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_cart_service.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_checkout_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_price_view.dart';
import 'package:petnest_saas/features/shop/widgets/store/storefront_theme.dart';

class StoreCartPage extends StatelessWidget {
  const StoreCartPage({
    super.key,
    required this.shopId,
    required this.shop,
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return StorefrontTheme(
      shopId: shopId,
      shopTheme: theme,
      builder: (BuildContext context, HomeThemeModel theme, _) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            foregroundColor: theme.textColor,
            title: const Text('購物車'),
          ),
          body: StreamBuilder<List<StoreCartItem>>(
            stream: StoreCartService.instance.streamCart(shopId),
            builder: (BuildContext context, AsyncSnapshot<List<StoreCartItem>> cartSnapshot) {
              final List<StoreCartItem> cartItems =
                  cartSnapshot.data ?? const <StoreCartItem>[];

              return StreamBuilder<List<StoreProductModel>>(
                stream: StoreProductService.instance.streamEnabledProducts(
                  shopId,
                ),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<StoreProductModel>> productSnapshot,
                    ) {
                      final Map<String, StoreProductModel> productsById =
                          <String, StoreProductModel>{
                            for (final StoreProductModel product
                                in productSnapshot.data ??
                                    const <StoreProductModel>[])
                              product.id: product,
                          };

                      if (cartItems.isEmpty) {
                        return const Center(child: Text('購物車是空的'));
                      }

                      return StoreEnabledPromotionsBuilder(
                        shopId: shopId,
                        builder: (BuildContext context, promotions) {
                          bool hasInvalid = false;
                          final List<StoreProductModel> allProducts =
                              productSnapshot.data ??
                              const <StoreProductModel>[];
                          final Map<String, int> quantities = <String, int>{};
                          final Map<String, int> bundleQuantities =
                              <String, int>{};
                          final List<Widget> tiles = <Widget>[];

                          for (final StoreCartItem cartItem in cartItems) {
                            if (cartItem.isBundle) {
                              StorePromotionModel? promo;
                              for (final StorePromotionModel item
                                  in promotions) {
                                if (item.id == cartItem.bundlePromotionId) {
                                  promo = item;
                                  break;
                                }
                              }
                              if (promo == null || !promo.isBundle) {
                                hasInvalid = true;
                                tiles.add(
                                  ListTile(
                                    title: const Text('套裝活動已結束'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        StoreCartService.instance.setBundle(
                                          shopId: shopId,
                                          bundlePromotionId:
                                              cartItem.bundlePromotionId,
                                          quantity: 0,
                                        );
                                      },
                                    ),
                                  ),
                                );
                                continue;
                              }
                              final StoreBundleQuote bundleQuote =
                                  StorePricingService.instance.quoteBundle(
                                    promotion: promo,
                                    sets: cartItem.quantity,
                                    products: allProducts,
                                  );
                              if (bundleQuote.soldOut) {
                                hasInvalid = true;
                              }
                              bundleQuantities[promo.id] = cartItem.quantity;
                              tiles.add(
                                Card(
                                  child: ListTile(
                                    title: Text(promo.name),
                                    subtitle: Text(
                                      '${bundleQuote.componentLabels.join(' + ')}\n'
                                      '套裝價 NT\$${bundleQuote.finalTotal}'
                                      '${bundleQuote.soldOut ? ' · 售罄' : ''}',
                                    ),
                                    isThreeLine: true,
                                    trailing: SizedBox(
                                      width: 132,
                                      child: Row(
                                        children: <Widget>[
                                          IconButton(
                                            onPressed: () {
                                              StoreCartService.instance
                                                  .setBundle(
                                                    shopId: shopId,
                                                    bundlePromotionId:
                                                        promo!.id,
                                                    quantity:
                                                        cartItem.quantity - 1,
                                                  );
                                            },
                                            icon: const Icon(Icons.remove),
                                          ),
                                          Text('${cartItem.quantity}'),
                                          IconButton(
                                            onPressed: bundleQuote.soldOut
                                                ? null
                                                : () {
                                                    StoreCartService.instance
                                                        .setBundle(
                                                          shopId: shopId,
                                                          bundlePromotionId:
                                                              promo!.id,
                                                          quantity:
                                                              cartItem
                                                                  .quantity +
                                                              1,
                                                        );
                                                  },
                                            icon: const Icon(Icons.add),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              continue;
                            }

                            final StoreProductModel? product =
                                productsById[cartItem.productId];
                            if (product == null) {
                              hasInvalid = true;
                              tiles.add(
                                ListTile(
                                  title: const Text('商品已下架'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      StoreCartService.instance.setItem(
                                        shopId: shopId,
                                        productId: cartItem.productId,
                                        quantity: 0,
                                      );
                                    },
                                  ),
                                ),
                              );
                              continue;
                            }

                            final int maxQty =
                                StoreStockHelper.maxPurchaseQuantity(product);
                            final bool outOfStock =
                                StoreStockHelper.isOutOfStock(product);
                            if (outOfStock ||
                                !product.hasInventoryLink ||
                                cartItem.quantity > maxQty) {
                              hasInvalid = true;
                            }
                            quantities[product.id] = cartItem.quantity;
                            final StorePricedLine line = StorePricingService
                                .instance
                                .quoteProduct(
                                  product: product,
                                  quantity: cartItem.quantity,
                                  promotions: promotions,
                                );

                            tiles.add(
                              Card(
                                child: ListTile(
                                  leading: product.imageUrl.isEmpty
                                      ? const Icon(Icons.shopping_bag_outlined)
                                      : Image.network(
                                          product.imageUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                  title: Text(product.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '單價 NT\$${line.originalUnitPrice}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      StoreProductPriceView(
                                        line: line,
                                        compact: true,
                                        color: theme.primaryColor,
                                      ),
                                      if (line.freeQuantity > 0)
                                        Text(
                                          '購買 ${line.purchaseQuantity} 件　贈送 ${line.freeQuantity} 件　共收到 ${line.fulfillmentQuantity} 件',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      Text(
                                        '商品金額 NT\$${line.finalSubtotal}'
                                        '${line.offerName.isEmpty ? '' : '　${line.offerName}'}'
                                        '${outOfStock ? ' · 缺貨' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: SizedBox(
                                    width: 132,
                                    child: Row(
                                      children: <Widget>[
                                        IconButton(
                                          onPressed: () {
                                            StoreCartService.instance.setItem(
                                              shopId: shopId,
                                              productId: product.id,
                                              quantity: cartItem.quantity - 1,
                                            );
                                          },
                                          icon: const Icon(Icons.remove),
                                        ),
                                        Text('${cartItem.quantity}'),
                                        IconButton(
                                          onPressed:
                                              outOfStock ||
                                                  !product.hasInventoryLink ||
                                                  cartItem.quantity >= maxQty
                                              ? null
                                              : () {
                                                  StoreCartService.instance
                                                      .setItem(
                                                        shopId: shopId,
                                                        productId: product.id,
                                                        quantity:
                                                            cartItem.quantity +
                                                            1,
                                                      );
                                                },
                                          icon: const Icon(Icons.add),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final StoreCartQuote quote = StorePricingService
                              .instance
                              .quoteCart(
                                products: allProducts,
                                quantities: quantities,
                                promotions: promotions,
                                bundleQuantities: bundleQuantities,
                              );
                          final int total = quote.finalSubtotal;

                          return Column(
                            children: <Widget>[
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: tiles,
                                ),
                              ),
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    12,
                                  ),
                                  child: Column(
                                    children: <Widget>[
                                      _CartTotalRow(
                                        label: '商品原價',
                                        value: 'NT\$ ${quote.originalSubtotal}',
                                      ),
                                      if (quote.itemPromotionDiscount > 0)
                                        _CartTotalRow(
                                          label: '商品優惠',
                                          value:
                                              '-NT\$ ${quote.itemPromotionDiscount}',
                                        ),
                                      if (quote.campaignDiscount > 0)
                                        _CartTotalRow(
                                          label: '活動優惠',
                                          value:
                                              '-NT\$ ${quote.campaignDiscount}',
                                        ),
                                      if (quote.quantityDiscount > 0)
                                        _CartTotalRow(
                                          label:
                                              quote
                                                      .quantityPromotion
                                                      ?.name
                                                      .isNotEmpty ==
                                                  true
                                              ? quote.quantityPromotion!.name
                                              : '滿件優惠',
                                          value:
                                              '-NT\$ ${quote.quantityDiscount}',
                                        ),
                                      if (quote.amountDiscount > 0)
                                        _CartTotalRow(
                                          label:
                                              quote
                                                      .amountPromotion
                                                      ?.name
                                                      .isNotEmpty ==
                                                  true
                                              ? quote.amountPromotion!.name
                                              : '滿額優惠',
                                          value:
                                              '-NT\$ ${quote.amountDiscount}',
                                        ),
                                      if (quote.bundleDiscount > 0)
                                        _CartTotalRow(
                                          label: '套裝優惠',
                                          value:
                                              '-NT\$ ${quote.bundleDiscount}',
                                        ),
                                      const Divider(),
                                      _CartTotalRow(
                                        label: '應付金額',
                                        value: 'NT\$ $total',
                                        emphasize: true,
                                        color: theme.primaryColor,
                                      ),
                                      if (hasInvalid)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Text('請先移除缺貨或已下架商品'),
                                        ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          onPressed: hasInvalid || total <= 0
                                              ? null
                                              : () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          StoreCheckoutPage(
                                                            shopId: shopId,
                                                            shop: shop,
                                                            theme: theme,
                                                            previewFinalSubtotal:
                                                                total,
                                                          ),
                                                    ),
                                                  );
                                                },
                                          child: const Text('前往結帳'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
              );
            },
          ),
        );
      },
    );
  }
}

class _CartTotalRow extends StatelessWidget {
  const _CartTotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 18 : 14,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
