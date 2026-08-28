// lib/features/shop/pages/storefront/store_home_page.dart
// 🛒 商城前台首頁

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_cart_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_product_detail_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_card.dart';

class StoreHomePage extends StatefulWidget {
  const StoreHomePage({
    super.key,
    required this.shopId,
    required this.shop,
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;

  @override
  State<StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<StoreHomePage> {
  final TextEditingController _search = TextEditingController();
  String _categoryId = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel theme = widget.theme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
        title: const Text('寵物賣場'),
        actions: <Widget>[
          IconButton(
            tooltip: '購物車',
            onPressed: () {
              if (FirebaseAuth.instance.currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請先登入')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => StoreCartPage(
                    shopId: widget.shopId,
                    shop: widget.shop,
                    theme: theme,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: StoreSettingsService.instance.streamSettings(widget.shopId),
        builder: (
          BuildContext context,
          AsyncSnapshot<Map<String, dynamic>> settingsSnapshot,
        ) {
          if (!StorefrontAccess.isStorefrontOpen(
            shop: widget.shop,
            settings: settingsSnapshot.data,
          )) {
            return const Center(child: Text('賣場目前未開放'));
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜尋商品',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              StreamBuilder<List<StoreCategoryModel>>(
                stream: StoreCategoryService.instance.streamCategories(
                  widget.shopId,
                ),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<StoreCategoryModel>> snapshot,
                ) {
                  final List<StoreCategoryModel> categories =
                      (snapshot.data ?? const <StoreCategoryModel>[])
                          .where((StoreCategoryModel item) => item.enabled)
                          .toList();
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: <Widget>[
                        _chip('全部', ''),
                        ...categories.map((StoreCategoryModel category) {
                          return _chip(category.name, category.id);
                        }),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<List<StoreProductModel>>(
                  stream: StoreProductService.instance.streamEnabledProducts(
                    widget.shopId,
                  ),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<StoreProductModel>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final String keyword = _search.text.trim().toLowerCase();
                    final List<StoreProductModel> products =
                        (snapshot.data ?? const <StoreProductModel>[])
                            .where((StoreProductModel product) {
                      final bool matchesCategory = _categoryId.isEmpty ||
                          product.categoryId == _categoryId;
                      final bool matchesSearch = keyword.isEmpty ||
                          product.name.toLowerCase().contains(keyword);
                      return matchesCategory && matchesSearch;
                    }).toList();

                    if (products.isEmpty) {
                      return const Center(child: Text('目前沒有商品'));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: products.length,
                      itemBuilder: (BuildContext context, int index) {
                        final StoreProductModel product = products[index];
                        final bool outOfStock =
                            StoreStockHelper.isOutOfStock(product);
                        return StoreProductCard(
                          product: product,
                          theme: theme,
                          stockLabel: StoreStockHelper.statusLabel(product),
                          outOfStock: outOfStock,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => StoreProductDetailPage(
                                  shopId: widget.shopId,
                                  shop: widget.shop,
                                  productId: product.id,
                                  theme: theme,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _categoryId == value,
        onSelected: (_) => setState(() => _categoryId = value),
      ),
    );
  }
}
