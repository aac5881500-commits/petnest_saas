// lib/features/shop/pages/store/shop_store_category_page.dart
// 🛒 商品分類管理

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';

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
          ? FloatingActionButton(
              onPressed: () => _edit(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<StoreCategoryModel>>(
        stream: StoreCategoryService.instance.streamCategories(shopId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<StoreCategoryModel>> snapshot,
        ) {
          final List<StoreCategoryModel> categories =
              snapshot.data ?? const <StoreCategoryModel>[];
          if (categories.isEmpty) {
            return const Center(child: Text('尚未建立分類'));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: categories.length,
            onReorder: canManage
                ? (int oldIndex, int newIndex) async {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final StoreCategoryModel moved = categories.removeAt(oldIndex);
                    categories.insert(newIndex, moved);
                    for (int i = 0; i < categories.length; i++) {
                      await StoreCategoryService.instance.updateCategory(
                        shopId: shopId,
                        categoryId: categories[i].id,
                        data: <String, dynamic>{'sortOrder': i},
                      );
                    }
                  }
                : (_, __) {},
            itemBuilder: (BuildContext context, int index) {
              final StoreCategoryModel category = categories[index];
              return Card(
                key: ValueKey<String>(category.id),
                child: SwitchListTile(
                  title: Text(category.name),
                  subtitle: Text(category.enabled ? '啟用中' : '已停用'),
                  value: category.enabled,
                  onChanged: canManage
                      ? (bool value) {
                          StoreCategoryService.instance.updateCategory(
                            shopId: shopId,
                            categoryId: category.id,
                            data: <String, dynamic>{'enabled': value},
                          );
                        }
                      : null,
                  secondary: canManage
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(context, category: category),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
