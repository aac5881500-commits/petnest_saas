// 檔案名稱：lib/features/shop/pages/store/shop_store_category_page.dart
// 功能說明：商品分類管理

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_empty_state.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_status_chip.dart';

class ShopStoreCategoryPage extends StatelessWidget {
  const ShopStoreCategoryPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  Future<void> _edit(
    BuildContext context, {
    StoreCategoryModel? category,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: category?.name ?? '',
    );
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(category == null ? '新增分類' : '編輯分類'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '分類名稱'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    final String name = controller.text.trim();
    controller.dispose();
    if (confirmed != true || name.isEmpty) {
      return;
    }
    if (category == null) {
      await StoreCategoryService.instance.createCategory(
        shopId: shopId,
        name: name,
        sortOrder: DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await StoreCategoryService.instance.updateCategory(
        shopId: shopId,
        categoryId: category.id,
        data: <String, dynamic>{'name': name},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('新增分類'),
            )
          : null,
      body: StreamBuilder<List<StoreCategoryModel>>(
        stream: StoreCategoryService.instance.streamCategories(shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<StoreCategoryModel>> snapshot,
            ) {
              final List<StoreCategoryModel> categories =
                  snapshot.data ?? const <StoreCategoryModel>[];
              if (categories.isEmpty) {
                return StoreEmptyState(
                  title: '尚未建立分類',
                  subtitle: '用分類整理商品，之後也能做分類優惠。',
                  actionLabel: canManage ? '新增分類' : null,
                  onAction: canManage ? () => _edit(context) : null,
                  icon: Icons.category_outlined,
                );
              }
              return StreamBuilder<List<StoreProductModel>>(
                stream: StoreProductService.instance.streamProducts(shopId),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<StoreProductModel>> productSnap,
                    ) {
                      final List<StoreProductModel> products =
                          productSnap.data ?? const <StoreProductModel>[];
                      return ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: categories.length,
                        onReorder: canManage
                            ? (int oldIndex, int newIndex) async {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final List<StoreCategoryModel> next =
                                    List<StoreCategoryModel>.from(categories);
                                final StoreCategoryModel moved = next.removeAt(
                                  oldIndex,
                                );
                                next.insert(newIndex, moved);
                                for (int i = 0; i < next.length; i++) {
                                  await StoreCategoryService.instance
                                      .updateCategory(
                                        shopId: shopId,
                                        categoryId: next[i].id,
                                        data: <String, dynamic>{'sortOrder': i},
                                      );
                                }
                              }
                            : (_, _) {},
                        itemBuilder: (BuildContext context, int index) {
                          final StoreCategoryModel category = categories[index];
                          final List<StoreProductModel> used = products
                              .where(
                                (StoreProductModel item) =>
                                    item.categoryId == category.id,
                              )
                              .toList();
                          final int enabledCount = used
                              .where((StoreProductModel item) => item.enabled)
                              .length;
                          return Card(
                            key: ValueKey<String>(category.id),
                            child: ListTile(
                              title: Text(category.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('商品 ${used.length}　上架 $enabledCount'),
                                  const SizedBox(height: 4),
                                  StoreStatusChip(
                                    label: category.enabled ? '啟用中' : '已停用',
                                    tone: category.enabled
                                        ? StoreStatusTone.success
                                        : StoreStatusTone.neutral,
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: canManage
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _edit(
                                            context,
                                            category: category,
                                          ),
                                        ),
                                        Switch(
                                          value: category.enabled,
                                          onChanged: (bool value) {
                                            if (!value && used.isNotEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '此分類仍有商品使用，已改為停用。請先移動商品再刪除分類。',
                                                  ),
                                                ),
                                              );
                                            }
                                            StoreCategoryService.instance
                                                .updateCategory(
                                                  shopId: shopId,
                                                  categoryId: category.id,
                                                  data: <String, dynamic>{
                                                    'enabled': value,
                                                  },
                                                );
                                          },
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
              );
            },
      ),
    );
  }
}
