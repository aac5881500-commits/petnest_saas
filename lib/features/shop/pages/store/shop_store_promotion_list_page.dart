// lib/features/shop/pages/store/shop_store_promotion_list_page.dart
// 🛒 商城促銷活動列表

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_promotion_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_product_form_page.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_promotion_form_page.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_promotion_type_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_empty_state.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_promotion_card.dart';

class ShopStorePromotionListPage extends StatefulWidget {
  const ShopStorePromotionListPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<ShopStorePromotionListPage> createState() =>
      _ShopStorePromotionListPageState();
}

class _ShopStorePromotionListPageState
    extends State<ShopStorePromotionListPage> {
  String _filter = 'all';

  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopStorePromotionTypePage(shopId: widget.shopId),
      ),
    );
  }

  void _openForm(StorePromotionModel promotion) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopStorePromotionFormPage(
          shopId: widget.shopId,
          promotion: promotion,
        ),
      ),
    );
  }

  Future<void> _duplicate(StorePromotionModel item) async {
    await StorePromotionService.instance.duplicatePromotion(
      shopId: widget.shopId,
      promotion: item,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製活動，預設停用，請改日期後再啟用')));
  }

  Future<void> _archive(StorePromotionModel item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item.usedOrderCount > 0 ? '封存活動' : '刪除活動'),
          content: Text(
            item.usedOrderCount > 0
                ? '此活動已被訂單使用過，將改為封存停用，不會硬刪。歷史訂單不受影響。'
                : '確定刪除此活動？',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(item.usedOrderCount > 0 ? '封存' : '刪除'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await StorePromotionService.instance.archiveOrDelete(
        shopId: widget.shopId,
        promotion: item,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('新增活動'),
            )
          : null,
      body: StreamBuilder<List<StorePromotionModel>>(
        stream: StorePromotionService.instance.streamPromotions(widget.shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<StorePromotionModel>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<StorePromotionModel> all =
                  snapshot.data ?? const <StorePromotionModel>[];
              if (all.isEmpty) {
                return StoreEmptyState(
                  title: '尚未建立活動',
                  subtitle:
                      '可建立：套裝優惠、多件優惠、分類優惠、滿額優惠。\n'
                      '商品自己的特價、打折、買 X 送 Y 請到商品編輯頁設定。',
                  actionLabel: widget.canManage ? '＋新增活動' : null,
                  onAction: widget.canManage ? _openCreate : null,
                  icon: Icons.local_offer_outlined,
                );
              }

              int countOf(String key) {
                return all
                    .where((StorePromotionModel item) => item.statusKey == key)
                    .length;
              }

              final List<StorePromotionModel> items = all.where((
                StorePromotionModel item,
              ) {
                return _filter == 'all' || item.statusKey == _filter;
              }).toList();

              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: <Widget>[
                        _summary('活動中', countOf('active')),
                        _summary('即將開始', countOf('upcoming')),
                        _summary('已結束', countOf('ended')),
                        _summary('已停用', countOf('disabled')),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: <Widget>[
                        _chip('全部', 'all'),
                        _chip('活動中', 'active'),
                        _chip('即將開始', 'upcoming'),
                        _chip('已結束', 'ended'),
                        _chip('已停用', 'disabled'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const StoreEmptyState(
                            title: '這個狀態沒有活動',
                            subtitle: '試試其他篩選，或新增一筆活動。',
                            icon: Icons.filter_alt_outlined,
                          )
                        : StreamBuilder<List<StoreProductModel>>(
                            stream: StoreProductService.instance.streamProducts(
                              widget.shopId,
                            ),
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<List<StoreProductModel>>
                                  productSnap,
                                ) {
                                  final Map<String, StoreProductModel>
                                  products = <String, StoreProductModel>{
                                    for (final StoreProductModel product
                                        in productSnap.data ??
                                            const <StoreProductModel>[])
                                      product.id: product,
                                  };
                                  return ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      88,
                                    ),
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (BuildContext context, int index) {
                                      final StorePromotionModel item =
                                          items[index];
                                      final String? firstProductId =
                                          item.productIds.isEmpty
                                          ? null
                                          : item.productIds.first;
                                      return StorePromotionCard(
                                        promotion: item,
                                        products: products,
                                        onView: () => _openForm(item),
                                        onEdit: widget.canManage
                                            ? () => _openForm(item)
                                            : null,
                                        onToggle: widget.canManage
                                            ? () {
                                                StorePromotionService.instance
                                                    .setEnabled(
                                                      shopId: widget.shopId,
                                                      promotionId: item.id,
                                                      enabled: !item.enabled,
                                                    );
                                              }
                                            : null,
                                        onDuplicate: widget.canManage
                                            ? () => _duplicate(item)
                                            : null,
                                        onArchive: widget.canManage
                                            ? () => _archive(item)
                                            : null,
                                        onOpenProduct:
                                            firstProductId != null &&
                                                products[firstProductId] != null
                                            ? () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        ShopStoreProductFormPage(
                                                          shopId: widget.shopId,
                                                          product:
                                                              products[firstProductId],
                                                        ),
                                                  ),
                                                );
                                              }
                                            : null,
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

  Widget _summary(String label, int count) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '$count',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
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
