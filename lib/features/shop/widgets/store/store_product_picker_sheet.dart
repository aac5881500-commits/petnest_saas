// lib/features/shop/widgets/store/store_product_picker_sheet.dart
// 🛒 促銷用商品多選 picker

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';

class StoreProductPickerSheet extends StatefulWidget {
  const StoreProductPickerSheet({
    super.key,
    required this.products,
    required this.selectedIds,
    this.categoryNames = const <String, String>{},
  });

  final List<StoreProductModel> products;
  final List<String> selectedIds;
  final Map<String, String> categoryNames;

  static Future<List<String>?> show({
    required BuildContext context,
    required List<StoreProductModel> products,
    required List<String> selectedIds,
    Map<String, String> categoryNames = const <String, String>{},
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StoreProductPickerSheet(
          products: products,
          selectedIds: selectedIds,
          categoryNames: categoryNames,
        );
      },
    );
  }

  @override
  State<StoreProductPickerSheet> createState() =>
      _StoreProductPickerSheetState();
}

class _StoreProductPickerSheetState extends State<StoreProductPickerSheet> {
  late final Set<String> _selected = widget.selectedIds.toSet();
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final List<StoreProductModel> filtered = widget.products.where((
      StoreProductModel product,
    ) {
      if (_keyword.trim().isEmpty) {
        return true;
      }
      final String key = _keyword.trim().toLowerCase();
      return product.name.toLowerCase().contains(key) ||
          product.categoryNameSnapshot.toLowerCase().contains(key) ||
          product.inventoryItemNameSnapshot.toLowerCase().contains(key);
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '選擇商品',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (String value) => setState(() => _keyword = value),
                decoration: const InputDecoration(
                  hintText: '搜尋商品名稱',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (BuildContext context, int index) {
                  final StoreProductModel product = filtered[index];
                  final String category = widget.categoryNames[product.categoryId] ??
                      product.categoryNameSnapshot;
                  return CheckboxListTile(
                    value: _selected.contains(product.id),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(product.id);
                        } else {
                          _selected.remove(product.id);
                        }
                      });
                    },
                    secondary: product.imageUrl.isEmpty
                        ? const Icon(Icons.shopping_bag_outlined)
                        : Image.network(
                            product.imageUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                    title: Text(product.name, maxLines: 1),
                    subtitle: Text(
                      '${category.isEmpty ? '未分類' : category}　'
                      'NT\$ ${product.price}　'
                      '${product.enabled ? StoreStockHelper.adminStatusLabel(product) : '未上架'}',
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: Text('完成（已選 ${_selected.length}）'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
