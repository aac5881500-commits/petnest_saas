// lib/features/shop/pages/storefront/store_product_detail_page.dart
// 🛒 商品詳情

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_cart_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_checkout_page.dart';

class StoreProductDetailPage extends StatefulWidget {
  const StoreProductDetailPage({
    super.key,
    required this.shopId,
    required this.shop,
    required this.productId,
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final String productId;
  final HomeThemeModel theme;

  @override
  State<StoreProductDetailPage> createState() => _StoreProductDetailPageState();
}

class _StoreProductDetailPageState extends State<StoreProductDetailPage> {
  int _quantity = 1;

  Future<bool> _ensureLogin() async {
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('請先登入')),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel theme = widget.theme;

    return StreamBuilder<StoreProductModel?>(
      stream: StoreProductService.instance
          .productsRef(widget.shopId)
          .doc(widget.productId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return StoreProductModel.fromMap(
          id: snapshot.id,
          data: snapshot.data()!,
        );
      }),
      builder: (
        BuildContext context,
        AsyncSnapshot<StoreProductModel?> snapshot,
      ) {
        final StoreProductModel? product = snapshot.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('商品詳情')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!product.enabled) {
          return Scaffold(
            appBar: AppBar(title: const Text('商品詳情')),
            body: const Center(child: Text('此商品已停售')),
          );
        }

        final int maxQty = StoreStockHelper.maxPurchaseQuantity(product);
        final bool outOfStock = StoreStockHelper.isOutOfStock(product);
        final String stockLabel = StoreStockHelper.statusLabel(product);
        final int quantity = product.useInventory && maxQty > 0
            ? _quantity.clamp(1, maxQty)
            : _quantity;

        return Scaffold(
              backgroundColor: theme.backgroundColor,
              appBar: AppBar(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textColor,
                title: const Text('商品詳情'),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 1.2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: product.imageUrl.isEmpty
                          ? ColoredBox(
                              color: theme.primaryColor.withValues(alpha: 0.08),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 48,
                                color: theme.primaryColor,
                              ),
                            )
                          : Image.network(product.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'NT\$ ${product.price}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                  if (product.useInventory) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      outOfStock ? '缺貨' : stockLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: outOfStock
                            ? const Color(0xFFB45309)
                            : theme.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    product.description.isEmpty ? '暫無商品介紹' : product.description,
                    style: TextStyle(
                      height: 1.5,
                      color: theme.textColor.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      const Text('數量'),
                      const Spacer(),
                      IconButton(
                        onPressed: _quantity <= 1
                            ? null
                            : () => setState(() => _quantity = quantity - 1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: outOfStock ||
                                (product.useInventory && quantity >= maxQty)
                            ? null
                            : () => setState(() => _quantity = quantity + 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: outOfStock
                              ? null
                              : () async {
                                  if (!await _ensureLogin()) {
                                    return;
                                  }
                                  try {
                                    await StoreCartService.instance
                                        .addOrIncrease(
                                      shopId: widget.shopId,
                                      productId: product.id,
                                      quantity: quantity,
                                    );
                                    if (!mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已加入購物車')),
                                    );
                                  } catch (error) {
                                    if (!mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                          child: const Text('加入購物車'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: outOfStock
                              ? null
                              : () async {
                                  if (!await _ensureLogin()) {
                                    return;
                                  }
                                  try {
                                    await StoreCartService.instance.setItem(
                                      shopId: widget.shopId,
                                      productId: product.id,
                                      quantity: quantity,
                                    );
                                    if (!mounted) {
                                      return;
                                    }
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => StoreCheckoutPage(
                                          shopId: widget.shopId,
                                          shop: widget.shop,
                                          theme: theme,
                                          buyNowProductId: product.id,
                                          buyNowQuantity: quantity,
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                          child: const Text('立即購買'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
      },
    );
  }
}
