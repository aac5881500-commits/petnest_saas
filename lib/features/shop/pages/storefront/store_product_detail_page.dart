// lib/features/shop/pages/storefront/store_product_detail_page.dart
// 🛒 商品詳情

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_cart_service.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_cart_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_availability_view.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_checkout_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_price_view.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_promotion_badge.dart';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('請先登入')));
    return false;
  }

  void _openCart() {
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
  }

  @override
  Widget build(BuildContext context) {
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
      builder:
          (BuildContext context, AsyncSnapshot<StoreProductModel?> snapshot) {
            final StoreProductModel? product = snapshot.data;
            if (product == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('商品詳情')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            if (!product.enabled || !product.hasInventoryLink) {
              return Scaffold(
                appBar: AppBar(title: const Text('商品詳情')),
                body: Center(
                  child: Text(
                    product.hasInventoryLink ? '此商品已停售' : '此商品暫不開放販售',
                  ),
                ),
              );
            }

            final int maxQty = StoreStockHelper.maxPurchaseQuantity(product);
            final bool outOfStock = StoreStockHelper.isOutOfStock(product);
            final int quantity = maxQty > 0 ? _quantity.clamp(1, maxQty) : 1;

            return StoreEnabledPromotionsBuilder(
              shopId: widget.shopId,
              builder:
                  (BuildContext context, List<StorePromotionModel> promotions) {
                    final StorePricedLine line = StorePricingService.instance
                        .quoteProduct(
                          product: product,
                          quantity: quantity,
                          promotions: promotions,
                        );
                    return StreamBuilder<Map<String, dynamic>>(
                      stream: StoreSettingsService.instance.streamSettings(
                        widget.shopId,
                      ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<Map<String, dynamic>> settingsSnap,
                          ) {
                            final StoreHomeDisplaySettings home =
                                StoreHomeDisplaySettings.fromMap(
                                  settingsSnap.data ??
                                      const <String, dynamic>{},
                                );
                            final HomeThemeModel theme = home.resolveTheme(
                              widget.theme,
                            );
                            final StoreAppearanceSetting look =
                                home.storeAppearance;
                            final Color primaryBtn = look.primaryButtonColor(
                              theme,
                            );
                            final Color secondaryBtn = look
                                .secondaryButtonColor(theme);
                            final bool showStock = home.showStockToCustomer;
                            return Scaffold(
                              backgroundColor: theme.backgroundColor,
                              appBar: AppBar(
                                backgroundColor: theme.cardColor,
                                foregroundColor: theme.textColor,
                                elevation: 0,
                                title: const Text('商品詳情'),
                              ),
                              body: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  24,
                                ),
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: ColoredBox(
                                        color: theme.cardColor,
                                        child: product.imageUrl.isEmpty
                                            ? Icon(
                                                Icons.shopping_bag_outlined,
                                                size: 48,
                                                color: theme.primaryColor,
                                              )
                                            : Opacity(
                                                opacity: outOfStock ? 0.6 : 1,
                                                child: Image.network(
                                                  product.imageUrl,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (line.hasOffer)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: <Widget>[
                                          StorePromotionBadge(
                                            line: line,
                                            color: theme.primaryColor,
                                            compact: false,
                                          ),
                                          if (outOfStock) ...<Widget>[
                                            const SizedBox(width: 8),
                                            Text(
                                              '售罄',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: theme.primaryColor,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  Text(
                                    product.name,
                                    style: TextStyle(
                                      fontSize: 22,
                                      height: 1.25,
                                      fontWeight: FontWeight.w800,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  StoreProductPriceView(
                                    line: line,
                                    color: theme.primaryColor,
                                    showBadge: false,
                                    showSaved: true,
                                    showUntil: true,
                                  ),
                                  if (line.itemPromotionType ==
                                      StoreItemPromotionTypes
                                          .buyXGetY) ...<Widget>[
                                    const SizedBox(height: 12),
                                    _BogoCard(
                                      theme: theme,
                                      line: line,
                                      quantity: quantity,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  StoreAvailabilityView(
                                    product: product,
                                    showStockToCustomer: showStock,
                                    color: outOfStock
                                        ? const Color(0xFFB45309)
                                        : theme.textColor.withValues(
                                            alpha: 0.68,
                                          ),
                                  ),
                                  if (outOfStock)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        '目前缺貨',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 18),
                                  Text(
                                    '商品介紹',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: theme.cardBorderColor,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        14,
                                        12,
                                      ),
                                      child: Text(
                                        product.description.trim().isEmpty
                                            ? '暫無商品介紹'
                                            : product.description.trim(),
                                        style: TextStyle(
                                          height: 1.55,
                                          color: theme.textColor.withValues(
                                            alpha: 0.82,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '購買數量',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _QuantitySelector(
                                    theme: theme,
                                    quantity: quantity,
                                    enabledDown: quantity > 1,
                                    enabledUp: !outOfStock && quantity < maxQty,
                                    onDown: () => setState(
                                      () => _quantity = quantity - 1,
                                    ),
                                    onUp: () => setState(
                                      () => _quantity = quantity + 1,
                                    ),
                                  ),
                                  if (!outOfStock && maxQty > 0) ...<Widget>[
                                    const SizedBox(height: 8),
                                    Text(
                                      '目前庫存最多可購買 $maxQty 件',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.textColor.withValues(
                                          alpha: 0.68,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (line.itemPromotionType ==
                                          StoreItemPromotionTypes.buyXGetY ||
                                      line.freeQuantity > 0) ...<Widget>[
                                    const SizedBox(height: 12),
                                    Text(
                                      '購買：${line.purchaseQuantity} 件\n'
                                      '贈送：${line.freeQuantity} 件\n'
                                      '實際取得：${line.fulfillmentQuantity} 件\n'
                                      '應付：${StoreMoney.ntd(line.finalSubtotal)}',
                                      style: TextStyle(
                                        height: 1.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.textColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              bottomNavigationBar: Material(
                                color: theme.cardColor,
                                elevation: 8,
                                child: SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      10,
                                      16,
                                      12,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: secondaryBtn,
                                              side: BorderSide(
                                                color: secondaryBtn,
                                              ),
                                            ),
                                            onPressed: outOfStock
                                                ? null
                                                : () async {
                                                    if (!await _ensureLogin()) {
                                                      return;
                                                    }
                                                    try {
                                                      await StoreCartService
                                                          .instance
                                                          .addOrIncrease(
                                                            shopId:
                                                                widget.shopId,
                                                            productId:
                                                                product.id,
                                                            quantity: quantity,
                                                          );
                                                      if (!mounted) {
                                                        return;
                                                      }
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: const Text(
                                                            '已加入購物車',
                                                          ),
                                                          action:
                                                              SnackBarAction(
                                                                label: '查看購物車',
                                                                onPressed:
                                                                    _openCart,
                                                              ),
                                                        ),
                                                      );
                                                    } catch (error) {
                                                      if (!mounted) {
                                                        return;
                                                      }
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '$error',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                            icon: const Icon(
                                              Icons.shopping_cart_outlined,
                                            ),
                                            label: Text(
                                              outOfStock ? '目前缺貨' : '加入購物車',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: primaryBtn,
                                              foregroundColor:
                                                  StoreAppearanceSetting.onColor(
                                                    primaryBtn,
                                                  ),
                                            ),
                                            onPressed: outOfStock
                                                ? null
                                                : () async {
                                                    if (!await _ensureLogin()) {
                                                      return;
                                                    }
                                                    try {
                                                      await StoreCartService
                                                          .instance
                                                          .setItem(
                                                            shopId:
                                                                widget.shopId,
                                                            productId:
                                                                product.id,
                                                            quantity: quantity,
                                                          );
                                                      if (!mounted) {
                                                        return;
                                                      }
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute<void>(
                                                          builder: (_) =>
                                                              StoreCheckoutPage(
                                                                shopId: widget
                                                                    .shopId,
                                                                shop:
                                                                    widget.shop,
                                                                theme: theme,
                                                                buyNowProductId:
                                                                    product.id,
                                                                buyNowQuantity:
                                                                    quantity,
                                                              ),
                                                        ),
                                                      );
                                                    } catch (error) {
                                                      if (!mounted) {
                                                        return;
                                                      }
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '$error',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                            child: Text(
                                              outOfStock ? '目前缺貨' : '立即購買',
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
                    );
                  },
            );
          },
    );
  }
}

class _BogoCard extends StatelessWidget {
  const _BogoCard({
    required this.theme,
    required this.line,
    required this.quantity,
  });

  final HomeThemeModel theme;
  final StorePricedLine line;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final int buy = line.product.itemPromotionBuyQuantity < 1
        ? 1
        : line.product.itemPromotionBuyQuantity;
    final int free = line.product.itemPromotionFreeQuantity < 1
        ? 1
        : line.product.itemPromotionFreeQuantity;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '🎁 買 $buy 送 $free',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '購買 $buy 件即可免費獲得 $free 件',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.72)),
            ),
            if (quantity > 0) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '目前選擇 $quantity 件，贈送 ${line.freeQuantity} 件，共收到 ${line.fulfillmentQuantity} 件',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.theme,
    required this.quantity,
    required this.enabledDown,
    required this.enabledUp,
    required this.onDown,
    required this.onUp,
  });

  final HomeThemeModel theme;
  final int quantity;
  final bool enabledDown;
  final bool enabledUp;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: enabledDown ? onDown : null,
            icon: const Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          IconButton(
            onPressed: enabledUp ? onUp : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
