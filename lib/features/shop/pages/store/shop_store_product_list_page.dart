// 檔案名稱：lib/features/shop/pages/store/shop_store_product_list_page.dart
// 功能說明：後台商品列表

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_promotion_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_product_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_admin_product_card.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_empty_state.dart';

class ShopStoreProductListPage extends StatefulWidget {
  const ShopStoreProductListPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<ShopStoreProductListPage> createState() =>
      _ShopStoreProductListPageState();
}

class _ShopStoreProductListPageState extends State<ShopStoreProductListPage> {
  String _filter = 'all';
  String _keyword = '';

  void _openForm([StoreProductModel? product]) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ShopStoreProductFormPage(shopId: widget.shopId, product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('新增商品'),
            )
          : null,
      body: StreamBuilder<List<StoreProductModel>>(
        stream: StoreProductService.instance.streamProducts(widget.shopId),
        builder: (BuildContext context, AsyncSnapshot<List<StoreProductModel>> productSnap) {
          return StreamBuilder<List<StorePromotionModel>>(
            stream: StorePromotionService.instance.streamEnabledPromotions(
              widget.shopId,
            ),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<StorePromotionModel>> promoSnap,
                ) {
                  return StreamBuilder<List<StoreCategoryModel>>(
                    stream: StoreCategoryService.instance.streamCategories(
                      widget.shopId,
                    ),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<StoreCategoryModel>> categorySnap,
                        ) {
                          if (productSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final List<StoreProductModel> all =
                              productSnap.data ?? const <StoreProductModel>[];
                          final List<StorePromotionModel> promotions =
                              promoSnap.data ?? const <StorePromotionModel>[];
                          final Map<String, String> categoryNames =
                              <String, String>{
                                for (final StoreCategoryModel item
                                    in categorySnap.data ??
                                        const <StoreCategoryModel>[])
                                  item.id: item.name,
                              };

                          if (all.isEmpty) {
                            return StoreEmptyState(
                              title: '尚未建立商品',
                              subtitle: '先從中央庫存選擇品項，再設定商城售價與上架資訊。',
                              actionLabel: widget.canManage ? '新增商品' : null,
                              onAction: widget.canManage
                                  ? () => _openForm()
                                  : null,
                              icon: Icons.shopping_bag_outlined,
                            );
                          }

                          final String key = _keyword.trim().toLowerCase();
                          final List<StoreProductModel> products = all.where((
                            StoreProductModel product,
                          ) {
                            final StorePricedLine line = StorePricingService
                                .instance
                                .quoteProduct(
                                  product: product,
                                  promotions: promotions,
                                );
                            final String stock =
                                StoreStockHelper.adminStatusLabel(product);
                            final bool matchesFilter = switch (_filter) {
                              'enabled' => product.enabled,
                              'disabled' => !product.enabled,
                              'featured' => product.featured,
                              'promo' => line.hasOffer,
                              'low' => stock == '低庫存',
                              'soldout' => stock == '售罄',
                              'unlinked' => !product.hasInventoryLink,
                              _ => true,
                            };
                            final bool matchesSearch =
                                key.isEmpty ||
                                product.name.toLowerCase().contains(key) ||
                                product.categoryNameSnapshot
                                    .toLowerCase()
                                    .contains(key) ||
                                product.inventoryItemNameSnapshot
                                    .toLowerCase()
                                    .contains(key);
                            return matchesFilter && matchesSearch;
                          }).toList();

                          return StreamBuilder<List<InventoryItemModel>>(
                            stream: InventoryService.instance.streamItems(
                              widget.shopId,
                            ),
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<List<InventoryItemModel>>
                                  inventorySnap,
                                ) {
                                  final Map<String, InventoryItemModel>
                                  itemsById = <String, InventoryItemModel>{
                                    for (final InventoryItemModel item
                                        in inventorySnap.data ??
                                            const <InventoryItemModel>[])
                                      item.id: item,
                                  };
                                  return Column(
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          8,
                                        ),
                                        child: TextField(
                                          onChanged: (String value) {
                                            setState(() => _keyword = value);
                                          },
                                          decoration: const InputDecoration(
                                            hintText: '搜尋商品名稱',
                                            prefixIcon: Icon(Icons.search),
                                            isDense: true,
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          8,
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            _chip('全部', 'all'),
                                            _chip('上架中', 'enabled'),
                                            _chip('未上架', 'disabled'),
                                            _chip('精選', 'featured'),
                                            _chip('活動中', 'promo'),
                                            _chip('低庫存', 'low'),
                                            _chip('售罄', 'soldout'),
                                            _chip('未連庫存', 'unlinked'),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: products.isEmpty
                                            ? const StoreEmptyState(
                                                title: '沒有符合的商品',
                                                subtitle: '試試其他篩選或搜尋條件。',
                                                icon: Icons.search_off_outlined,
                                              )
                                            : ListView.separated(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      0,
                                                      16,
                                                      88,
                                                    ),
                                                itemCount: products.length,
                                                separatorBuilder: (_, _) =>
                                                    const SizedBox(height: 10),
                                                itemBuilder:
                                                    (
                                                      BuildContext context,
                                                      int index,
                                                    ) {
                                                      final StoreProductModel
                                                      product = products[index];
                                                      return StoreAdminProductCard(
                                                        product: product,
                                                        inventoryItem:
                                                            itemsById[product
                                                                .inventoryItemId],
                                                        categoryName:
                                                            categoryNames[product
                                                                .categoryId] ??
                                                            product
                                                                .categoryNameSnapshot,
                                                        priced:
                                                            StorePricingService
                                                                .instance
                                                                .quoteProduct(
                                                                  product:
                                                                      product,
                                                                  promotions:
                                                                      promotions,
                                                                ),
                                                        onTap: widget.canManage
                                                            ? () => _openForm(
                                                                product,
                                                              )
                                                            : () {},
                                                      );
                                                    },
                                              ),
                                      ),
                                    ],
                                  );
                                },
                          );
                        },
                  );
                },
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
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}
