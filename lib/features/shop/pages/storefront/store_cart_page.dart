// lib/features/shop/pages/storefront/store_cart_page.dart
// 🛒 每店獨立購物車。不扣除 currentStock。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_cart_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_checkout_page.dart';

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
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
        title: const Text('購物車'),
      ),
      body: StreamBuilder<List<StoreCartItem>>(
        stream: StoreCartService.instance.streamCart(shopId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<StoreCartItem>> cartSnapshot,
        ) {
          final List<StoreCartItem> cartItems =
              cartSnapshot.data ?? const <StoreCartItem>[];

          return StreamBuilder<List<StoreProductModel>>(
            stream: StoreProductService.instance.streamEnabledProducts(shopId),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<StoreProductModel>> productSnapshot,
            ) {
              final Map<String, StoreProductModel> productsById =
                  <String, StoreProductModel>{
                for (final StoreProductModel product
                    in productSnapshot.data ?? const <StoreProductModel>[])
                  product.id: product,
              };

              if (cartItems.isEmpty) {
                return const Center(child: Text('購物車是空的'));
              }

              int total = 0;
              bool hasInvalid = false;
              final List<Widget> tiles = <Widget>[];

              for (final StoreCartItem cartItem in cartItems) {
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
                final bool outOfStock = StoreStockHelper.isOutOfStock(product);
                if (outOfStock ||
                    (product.useInventory && cartItem.quantity > maxQty)) {
                  hasInvalid = true;
                }
                final int line = product.price * cartItem.quantity;
                total += line;

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
                      subtitle: Text(
                        'NT\$ ${product.price}'
                        '${outOfStock ? ' · 缺貨' : ''}',
                      ),
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
                              onPressed: outOfStock ||
                                      (product.useInventory &&
                                          cartItem.quantity >= maxQty)
                                  ? null
                                  : () {
                                      StoreCartService.instance.setItem(
                                        shopId: shopId,
                                        productId: product.id,
                                        quantity: cartItem.quantity + 1,
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
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Column(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Text('總計'),
                                  const Spacer(),
                                  Text(
                                    'NT\$ $total',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
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
                                              builder: (_) => StoreCheckoutPage(
                                                shopId: shopId,
                                                shop: shop,
                                                theme: theme,
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
      ),
    );
  }
}
